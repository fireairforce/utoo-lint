const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const jest_fn_call = @import("jest_fn_call.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "jest/valid-expect";

pub const Options = struct {
    always_await: bool = false,
    async_matchers: core.JestValidExpectAsyncMatchers = .{},
    min_args: f64 = 1,
    max_args: f64 = 1,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    global_aliases: core.JestGlobalAliases,
    options: Options,
) Allocator.Error!void {
    var resolver = try jest_fn_call.Resolver.init(allocator, tree, symbol_table, global_aliases);
    defer resolver.deinit();

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .resolver = &resolver,
        .options = options,
    };
    defer visitor.reported_async_nodes.deinit(allocator);
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    resolver: *const jest_fn_call.Resolver,
    options: Options,
    reported_async_nodes: std.AutoHashMapUnmanaged(ast.NodeIndex, void) = .empty,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.resolver.resolveFunctionReference(call.callee) != .expect) return .proceed;

        const chain = collectExpectChain(ctx.tree, index, ctx);
        const matcher_call = chain.matcher_call orelse {
            if (chain.member_count == 0) {
                try core.addDiagnostic(
                    self.allocator,
                    self.diagnostics,
                    .warning,
                    id,
                    "Expect must have a corresponding matcher call",
                    ctx.tree.span(index),
                );
            } else {
                const last = chain.members[chain.member_count - 1];
                try core.addDiagnostic(
                    self.allocator,
                    self.diagnostics,
                    .warning,
                    id,
                    if (isModifier(last.name))
                        "Expect must have a corresponding matcher call"
                    else
                        "Matchers must be called to assert",
                    ctx.tree.span(last.node),
                );
            }
            return .proceed;
        };

        if (chain.member_count == 0) {
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                "Expect must have a corresponding matcher call",
                ctx.tree.span(matcher_call.index),
            );
            return .proceed;
        }

        const modifiers = chain.members[0 .. chain.member_count - 1];
        if (!validModifiers(modifiers)) {
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                "Expect has an unknown modifier",
                ctx.tree.span(matcher_call.index),
            );
            return .proceed;
        }

        try self.checkArguments(ctx.tree, call);

        const matcher = chain.members[chain.member_count - 1].name;
        var async_assertion = self.options.async_matchers.contains(matcher);
        for (modifiers) |modifier| {
            if (!std.mem.eql(u8, modifier.name, "not")) async_assertion = true;
        }
        if (async_assertion) try self.checkAsyncAssertion(ctx.tree, matcher_call, ctx);
        return .proceed;
    }

    fn checkArguments(self: *Visitor, tree: *const ast.Tree, call: ast.CallExpression) Allocator.Error!void {
        const arguments = tree.extra(call.arguments);
        const count: f64 = @floatFromInt(arguments.len);
        if (count < self.options.min_args) {
            const amount = self.options.min_args;
            const message = try std.fmt.allocPrint(
                self.allocator,
                "Expect requires at least {d} argument{s}",
                .{ amount, if (amount == 1) "" else "s" },
            );
            defer self.allocator.free(message);
            const callee_span = tree.span(call.callee);
            const end = @min(callee_span.end + 1, tree.source.len);
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                message,
                .{ .start = callee_span.end, .end = end },
            );
        }
        if (count > self.options.max_args) {
            const first_extra_float = @floor(self.options.max_args);
            const first_extra: usize = @intFromFloat(first_extra_float);
            if (first_extra < arguments.len) {
                const amount = self.options.max_args;
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "Expect takes at most {d} argument{s}",
                    .{ amount, if (amount == 1) "" else "s" },
                );
                defer self.allocator.free(message);
                const first_span = tree.span(arguments[first_extra]);
                const last_span = tree.span(arguments[arguments.len - 1]);
                try core.addDiagnostic(
                    self.allocator,
                    self.diagnostics,
                    .warning,
                    id,
                    message,
                    .{ .start = first_span.start, .end = last_span.end },
                );
            }
        }
    }

    fn checkAsyncAssertion(
        self: *Visitor,
        tree: *const ast.Tree,
        matcher_call: PathNode,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!void {
        const assertion_target = thenifiedTarget(tree, matcher_call, ctx);
        const promise_target = promiseWrapperTarget(tree, assertion_target, ctx);
        const wrapped = promise_target.index != assertion_target.index;
        const target = thenifiedTarget(tree, promise_target, ctx);

        if (acceptableParent(tree, target, ctx, !self.options.always_await)) return;
        const entry = try self.reported_async_nodes.getOrPut(self.allocator, target.index);
        if (entry.found_existing) return;

        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            if (wrapped)
                if (self.options.always_await)
                    "Promises which return async assertions must be awaited"
                else
                    "Promises which return async assertions must be awaited or returned"
            else if (self.options.always_await)
                "Async assertions must be awaited"
            else
                "Async assertions must be awaited or returned",
            tree.span(target.index),
        );
    }
};

const ChainMember = struct {
    name: []const u8,
    node: ast.NodeIndex,
};

const ExpectChain = struct {
    members: [16]ChainMember = undefined,
    member_count: usize = 0,
    matcher_call: ?PathNode = null,

    fn append(self: *ExpectChain, member: ChainMember) bool {
        if (self.member_count == self.members.len) return false;
        self.members[self.member_count] = member;
        self.member_count += 1;
        return true;
    }
};

const PathNode = struct {
    index: ast.NodeIndex,
    depth: usize,
};

fn collectExpectChain(tree: *const ast.Tree, expect_call: ast.NodeIndex, ctx: *traverser.basic.Ctx) ExpectChain {
    var result = ExpectChain{};
    var target = expect_call;
    var depth: usize = 1;

    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .chain_expression,
            .parenthesized_expression,
            .ts_as_expression,
            .ts_satisfies_expression,
            .ts_non_null_expression,
            .ts_type_assertion,
            => {
                target = ancestor;
                continue;
            },
            .member_expression => |member| {
                if (unwrapTransparent(tree, member.object) != unwrapTransparent(tree, target)) return result;
                const name = staticPropertyName(tree, member) orelse return result;
                if (!result.append(.{ .name = name, .node = member.property })) return result;
                target = ancestor;
            },
            .call_expression => |call| {
                if (unwrapTransparent(tree, call.callee) != unwrapTransparent(tree, target)) return result;
                result.matcher_call = .{ .index = ancestor, .depth = depth };
                return result;
            },
            else => return result,
        }
    }
    return result;
}

fn validModifiers(modifiers: []const ChainMember) bool {
    return switch (modifiers.len) {
        0 => true,
        1 => isModifier(modifiers[0].name),
        2 => (std.mem.eql(u8, modifiers[0].name, "resolves") or
            std.mem.eql(u8, modifiers[0].name, "rejects")) and
            std.mem.eql(u8, modifiers[1].name, "not"),
        else => false,
    };
}

fn isModifier(name: []const u8) bool {
    return std.mem.eql(u8, name, "not") or
        std.mem.eql(u8, name, "resolves") or
        std.mem.eql(u8, name, "rejects");
}

fn thenifiedTarget(tree: *const ast.Tree, initial: PathNode, ctx: *traverser.basic.Ctx) PathNode {
    var target = initial;
    while (true) {
        const member_node = nextNonTransparentAncestor(tree, ctx, target.depth + 1) orelse return target;
        const member = switch (tree.data(member_node.index)) {
            .member_expression => |value| value,
            else => return target,
        };
        if (unwrapTransparent(tree, member.object) != unwrapTransparent(tree, target.index)) return target;
        const property = staticPropertyName(tree, member) orelse return target;
        if (!std.mem.eql(u8, property, "then") and !std.mem.eql(u8, property, "catch")) return target;

        const call_node = nextNonTransparentAncestor(tree, ctx, member_node.depth + 1) orelse return target;
        const call = switch (tree.data(call_node.index)) {
            .call_expression => |value| value,
            else => return target,
        };
        if (unwrapTransparent(tree, call.callee) != member_node.index) return target;
        target = call_node;
    }
}

fn promiseWrapperTarget(tree: *const ast.Tree, target: PathNode, ctx: *traverser.basic.Ctx) PathNode {
    const parent = nextNonTransparentAncestor(tree, ctx, target.depth + 1) orelse return target;
    switch (tree.data(parent.index)) {
        .call_expression => |call| {
            if (isPromiseCall(tree, call) and argumentsContain(tree, call, target.index)) return parent;
        },
        .array_expression => |array| {
            if (!nodesContain(tree, tree.extra(array.elements), target.index)) return target;
            const call_node = nextNonTransparentAncestor(tree, ctx, parent.depth + 1) orelse return target;
            const call = switch (tree.data(call_node.index)) {
                .call_expression => |value| value,
                else => return target,
            };
            if (isPromiseCall(tree, call) and argumentsContain(tree, call, parent.index)) return call_node;
        },
        else => {},
    }
    return target;
}

fn acceptableParent(
    tree: *const ast.Tree,
    initial: PathNode,
    ctx: *traverser.basic.Ctx,
    allow_return: bool,
) bool {
    var target = initial;
    while (nextNonTransparentAncestor(tree, ctx, target.depth + 1)) |parent| {
        switch (tree.data(parent.index)) {
            .conditional_expression => {
                target = parent;
                continue;
            },
            .await_expression => |expression| return unwrapTransparent(tree, expression.argument) == unwrapTransparent(tree, target.index),
            .return_statement => |statement| return allow_return and unwrapTransparent(tree, statement.argument) == unwrapTransparent(tree, target.index),
            .arrow_function_expression => |arrow| return arrow.expression and unwrapTransparent(tree, arrow.body) == unwrapTransparent(tree, target.index),
            else => return false,
        }
    }
    return false;
}

fn isPromiseCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |value| value,
        else => return false,
    };
    return identifierReferenceNamed(tree, member.object, "Promise") and staticPropertyName(tree, member) != null;
}

fn argumentsContain(tree: *const ast.Tree, call: ast.CallExpression, expected: ast.NodeIndex) bool {
    return nodesContain(tree, tree.extra(call.arguments), expected);
}

fn nodesContain(tree: *const ast.Tree, nodes: []const ast.NodeIndex, expected: ast.NodeIndex) bool {
    for (nodes) |node| {
        if (unwrapTransparent(tree, node) == unwrapTransparent(tree, expected)) return true;
    }
    return false;
}

fn identifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), expected),
        else => false,
    };
}

fn staticPropertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    return switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| if (member.computed) null else tree.string(identifier.name),
        .string_literal => |literal| if (member.computed) tree.string(literal.value) else null,
        .template_literal => |literal| if (member.computed) templateStringValue(tree, literal) else null,
        else => null,
    };
}

fn templateStringValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;
    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return "";
    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
}

fn nextNonTransparentAncestor(
    tree: *const ast.Tree,
    ctx: *traverser.basic.Ctx,
    start_depth: usize,
) ?PathNode {
    var depth = start_depth;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .chain_expression,
            .parenthesized_expression,
            .ts_as_expression,
            .ts_satisfies_expression,
            .ts_non_null_expression,
            .ts_type_assertion,
            => continue,
            else => return .{ .index = ancestor, .depth = depth },
        }
    }
    return null;
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;
    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |expression| current = expression.expression,
            .parenthesized_expression => |expression| current = expression.expression,
            .ts_as_expression => |expression| current = expression.expression,
            .ts_satisfies_expression => |expression| current = expression.expression,
            .ts_non_null_expression => |expression| current = expression.expression,
            .ts_type_assertion => |expression| current = expression.expression,
            else => return current,
        }
    }
    return current;
}
