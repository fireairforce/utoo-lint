const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const jest_fn_call = @import("jest_fn_call.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;
const SymbolId = traverser.semantic.SymbolId;

pub const id = "jest/valid-expect-in-promise";

const message = "This promise should either be returned or awaited to ensure the expects in its chain are called";

const PromiseChain = struct {
    node: ast.NodeIndex,
    has_expect: bool = false,
    directly_in_test: bool,
};

const Candidate = struct {
    report_node: ast.NodeIndex,
    scope_function: ast.NodeIndex,
    symbol: ?SymbolId,
    start: u32,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    global_aliases: core.JestGlobalAliases,
) Allocator.Error!void {
    var resolver = try jest_fn_call.Resolver.init(allocator, tree, symbol_table, global_aliases);
    defer resolver.deinit();

    var visitor = Visitor{
        .allocator = allocator,
        .resolver = &resolver,
        .symbol_table = symbol_table,
    };
    defer visitor.chains.deinit(allocator);
    defer visitor.candidates.deinit(allocator);
    try visitor.candidates.ensureTotalCapacity(allocator, tree.nodes.len);
    try traverser.basic.traverse(Visitor, tree, &visitor);

    for (visitor.candidates.items) |candidate| {
        if (candidate.symbol) |symbol| {
            var scanner = UsageScanner{
                .resolver = &resolver,
                .symbol_table = symbol_table,
                .symbol = symbol,
                .scope_function = candidate.scope_function,
                .start = candidate.start,
            };
            var subtree = tree.*;
            subtree.root = candidate.scope_function;
            try traverser.basic.traverse(UsageScanner, &subtree, &scanner);
            if (scanner.consumed) continue;
        }

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            message,
            tree.span(candidate.report_node),
        );
    }
}

const Visitor = struct {
    allocator: Allocator,
    resolver: *const jest_fn_call.Resolver,
    symbol_table: traverser.semantic.SymbolTable,
    chains: std.ArrayList(PromiseChain) = .empty,
    candidates: std.ArrayList(Candidate) = .empty,

    pub fn enter_call_expression(
        self: *Visitor,
        call_expression: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (isPromiseChainCall(ctx.tree, call_expression)) {
            const directly_in_test = directTestScope(ctx.tree, self.resolver, index, &ctx.path) != null;
            if (directly_in_test or self.chains.items.len != 0) {
                try self.chains.append(self.allocator, .{
                    .node = index,
                    .directly_in_test = directly_in_test,
                });
            }
            return .proceed;
        }

        if (self.chains.items.len != 0) {
            const parsed = self.resolver.parseCall(call_expression, index, ctx.path.parent());
            if (parsed) |call| {
                if (call.function.kind() == .expect) {
                    self.chains.items[self.chains.items.len - 1].has_expect = true;
                }
            }
        }
        return .proceed;
    }

    pub fn exit_call_expression(
        self: *Visitor,
        call_expression: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) void {
        if (!isPromiseChainCall(ctx.tree, call_expression)) return;
        if (self.chains.items.len == 0) return;
        const chain = self.chains.items[self.chains.items.len - 1];
        if (chain.node != index) return;
        _ = self.chains.pop();

        if (!chain.has_expect or !chain.directly_in_test) return;
        const scope_function = directTestScope(ctx.tree, self.resolver, index, &ctx.path) orelse return;
        const top = topMostCall(ctx.tree, index, &ctx.path);
        const parent = top.parent orelse return;

        switch (ctx.tree.data(parent)) {
            .return_statement, .await_expression => return,
            .variable_declarator => |declarator| {
                if (declarator.init != top.value) return;
                const id_node = unwrapTransparent(ctx.tree, declarator.id);
                const symbol = switch (ctx.tree.data(id_node)) {
                    .binding_identifier => self.symbol_table.symbolOf(id_node),
                    else => return,
                };
                self.addCandidate(parent, scope_function, symbol, ctx.tree.span(parent).end);
            },
            .assignment_expression => |assignment| {
                if (assignment.right != top.value) return;
                const left = unwrapTransparent(ctx.tree, assignment.left);
                const symbol = referenceSymbol(self.symbol_table, left);
                self.addCandidate(parent, scope_function, symbol, ctx.tree.span(parent).end);
            },
            .expression_statement => |statement| {
                if (statement.expression != top.value) return;
                self.addCandidate(top.call, scope_function, null, ctx.tree.span(top.value).end);
            },
            else => return,
        }
    }

    fn addCandidate(
        self: *Visitor,
        report_node: ast.NodeIndex,
        scope_function: ast.NodeIndex,
        symbol: ?SymbolId,
        start: u32,
    ) void {
        for (self.candidates.items) |candidate| {
            if (candidate.report_node == report_node) return;
        }
        self.candidates.appendAssumeCapacity(.{
            .report_node = report_node,
            .scope_function = scope_function,
            .symbol = symbol,
            .start = start,
        });
    }
};

const UsageScanner = struct {
    resolver: *const jest_fn_call.Resolver,
    symbol_table: traverser.semantic.SymbolTable,
    symbol: SymbolId,
    scope_function: ast.NodeIndex,
    start: u32,
    consumed: bool = false,
    stopped: bool = false,

    pub fn enter_function(
        self: *UsageScanner,
        _: ast.Function,
        index: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) traverser.Action {
        return if (index == self.scope_function) .proceed else .skip;
    }

    pub fn enter_arrow_function_expression(
        self: *UsageScanner,
        _: ast.ArrowFunctionExpression,
        index: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) traverser.Action {
        return if (index == self.scope_function) .proceed else .skip;
    }

    pub fn enter_return_statement(
        self: *UsageScanner,
        statement: ast.ReturnStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) traverser.Action {
        if (!self.shouldCheck(ctx.tree, index)) return .proceed;
        if (promiseMethodUsesValue(ctx.tree, self.symbol_table, statement.argument, self.symbol)) {
            self.consumed = true;
        } else {
            self.stopped = true;
        }
        return .proceed;
    }

    pub fn enter_await_expression(
        self: *UsageScanner,
        expression: ast.AwaitExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) traverser.Action {
        if (!self.shouldCheck(ctx.tree, index)) return .proceed;
        if (promiseMethodUsesValue(ctx.tree, self.symbol_table, expression.argument, self.symbol)) {
            self.consumed = true;
        }
        return .proceed;
    }

    pub fn enter_assignment_expression(
        self: *UsageScanner,
        expression: ast.AssignmentExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) traverser.Action {
        if (!self.shouldCheck(ctx.tree, index)) return .proceed;
        if (!nodeReferencesSymbol(ctx.tree, self.symbol_table, expression.left, self.symbol)) return .proceed;
        if (!isChainedAssignment(ctx.tree, self.symbol_table, expression.right, self.symbol)) {
            self.stopped = true;
        }
        return .proceed;
    }

    pub fn enter_call_expression(
        self: *UsageScanner,
        call_expression: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) traverser.Action {
        if (!self.shouldCheck(ctx.tree, index)) return .proceed;
        const call = self.resolver.parseCall(call_expression, index, ctx.path.parent()) orelse return .proceed;
        if (call.function.kind() != .expect) return .proceed;
        if (call.memberNamed("resolves") == null and call.memberNamed("rejects") == null) return .proceed;

        const expect_call = leftMostCall(ctx.tree, index) orelse return .proceed;
        const arguments = ctx.tree.extra(expect_call.arguments);
        if (arguments.len != 0 and nodeReferencesSymbol(ctx.tree, self.symbol_table, arguments[0], self.symbol)) {
            self.consumed = true;
        }
        return .proceed;
    }

    fn shouldCheck(self: *const UsageScanner, tree: *const ast.Tree, index: ast.NodeIndex) bool {
        return !self.consumed and !self.stopped and tree.span(index).start >= self.start;
    }
};

const TopMostCall = struct {
    call: ast.NodeIndex,
    value: ast.NodeIndex,
    parent: ?ast.NodeIndex,
};

fn topMostCall(tree: *const ast.Tree, index: ast.NodeIndex, path: *const parser.traverser.NodePath) TopMostCall {
    var call_index = index;
    var value = index;
    var depth: usize = 1;

    while (path.ancestor(depth)) |parent| {
        switch (tree.data(parent)) {
            .member_expression => |member| {
                if (member.object != value) break;
                value = parent;
            },
            .call_expression => |call| {
                if (call.callee != value) break;
                call_index = parent;
                value = parent;
            },
            .chain_expression => |expression| {
                if (expression.expression != value) break;
                value = parent;
            },
            .parenthesized_expression => |expression| {
                if (expression.expression != value) break;
                value = parent;
            },
            .ts_as_expression => |expression| {
                if (expression.expression != value) break;
                value = parent;
            },
            .ts_satisfies_expression => |expression| {
                if (expression.expression != value) break;
                value = parent;
            },
            .ts_non_null_expression => |expression| {
                if (expression.expression != value) break;
                value = parent;
            },
            .ts_type_assertion => |expression| {
                if (expression.expression != value) break;
                value = parent;
            },
            else => break,
        }
        depth += 1;
    }

    return .{ .call = call_index, .value = value, .parent = path.ancestor(depth) };
}

fn directTestScope(
    tree: *const ast.Tree,
    resolver: *const jest_fn_call.Resolver,
    _: ast.NodeIndex,
    path: *const parser.traverser.NodePath,
) ?ast.NodeIndex {
    var depth: usize = 1;
    while (path.ancestor(depth)) |ancestor| : (depth += 1) {
        const params = switch (tree.data(ancestor)) {
            .function => |function| function.params,
            .arrow_function_expression => |arrow| arrow.params,
            else => continue,
        };

        var callback_value = ancestor;
        var parent_depth = depth + 1;
        while (path.ancestor(parent_depth)) |wrapper| : (parent_depth += 1) {
            if (!transparentContains(tree, wrapper, callback_value)) break;
            callback_value = wrapper;
        }
        const call_index = path.ancestor(parent_depth) orelse return null;
        const call_expression = switch (tree.data(call_index)) {
            .call_expression => |call| call,
            else => return null,
        };
        const arguments = tree.extra(call_expression.arguments);
        if (arguments.len < 2 or arguments[1] != callback_value) return null;
        const parsed = resolver.parseCall(call_expression, call_index, path.ancestor(parent_depth + 1)) orelse return null;
        if (parsed.function.kind() != .test_case) return null;

        const parameter_count = formalParameterCount(tree, params);
        if (parsed.memberNamed("each") != null) {
            if (!containsTaggedTemplate(tree, call_expression.callee)) return null;
            if (parameter_count == 2) return null;
        } else if (parameter_count == 1) {
            return null;
        }
        return ancestor;
    }
    return null;
}

fn formalParameterCount(tree: *const ast.Tree, params_index: ast.NodeIndex) usize {
    return switch (tree.data(params_index)) {
        .formal_parameters => |params| tree.extra(params.items).len,
        else => 0,
    };
}

fn containsTaggedTemplate(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const current = unwrapTransparent(tree, index);
    return switch (tree.data(current)) {
        .tagged_template_expression => true,
        .call_expression => |call| containsTaggedTemplate(tree, call.callee),
        .member_expression => |member| containsTaggedTemplate(tree, member.object),
        else => false,
    };
}

fn isPromiseChainCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    const name = staticPropertyName(tree, member.property, member.computed) orelse return false;
    const argument_count = tree.extra(call.arguments).len;
    if (argument_count == 0) return false;
    if (std.mem.eql(u8, name, "then")) return argument_count < 3;
    if (std.mem.eql(u8, name, "catch") or std.mem.eql(u8, name, "finally")) return argument_count < 2;
    return false;
}

fn promiseMethodUsesValue(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
    symbol: SymbolId,
) bool {
    if (index == .null) return false;
    const current = unwrapTransparent(tree, index);
    if (nodeReferencesSymbol(tree, symbol_table, current, symbol)) return true;

    const call = switch (tree.data(current)) {
        .call_expression => |call| call,
        else => return false,
    };
    const method = promiseStaticMethod(tree, call) orelse return false;
    const arguments = tree.extra(call.arguments);
    if ((std.mem.eql(u8, method, "resolve") or std.mem.eql(u8, method, "reject")) and arguments.len == 1) {
        return nodeReferencesSymbol(tree, symbol_table, arguments[0], symbol);
    }
    if ((!std.mem.eql(u8, method, "all") and !std.mem.eql(u8, method, "allSettled")) or arguments.len == 0) {
        return false;
    }
    const array = switch (tree.data(unwrapTransparent(tree, arguments[0]))) {
        .array_expression => |array| array,
        else => return false,
    };
    for (tree.extra(array.elements)) |element| {
        if (nodeReferencesSymbol(tree, symbol_table, element, symbol)) return true;
    }
    return false;
}

fn promiseStaticMethod(tree: *const ast.Tree, call: ast.CallExpression) ?[]const u8 {
    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return null,
    };
    const object = unwrapTransparent(tree, member.object);
    const object_name = switch (tree.data(object)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => return null,
    };
    if (!std.mem.eql(u8, object_name, "Promise")) return null;
    return staticPropertyName(tree, member.property, member.computed);
}

fn isChainedAssignment(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
    symbol: SymbolId,
) bool {
    const current = unwrapTransparent(tree, index);
    const call = switch (tree.data(current)) {
        .call_expression => |call| call,
        else => return false,
    };
    if (!isPromiseChainCall(tree, call)) return false;
    var object = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member.object,
        else => return false,
    };
    while (true) {
        object = unwrapTransparent(tree, object);
        switch (tree.data(object)) {
            .call_expression => |inner| object = inner.callee,
            .member_expression => |member| object = member.object,
            else => break,
        }
    }
    return nodeReferencesSymbol(tree, symbol_table, object, symbol);
}

fn leftMostCall(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.CallExpression {
    var current = unwrapTransparent(tree, index);
    var result: ?ast.CallExpression = null;
    while (true) {
        switch (tree.data(current)) {
            .call_expression => |call| {
                result = call;
                current = unwrapTransparent(tree, call.callee);
            },
            .member_expression => |member| current = unwrapTransparent(tree, member.object),
            .tagged_template_expression => |tagged| current = unwrapTransparent(tree, tagged.tag),
            else => return result,
        }
    }
}

fn referenceSymbol(symbol_table: traverser.semantic.SymbolTable, index: ast.NodeIndex) ?SymbolId {
    const reference_id = symbol_table.model.referenceOf(index) orelse return null;
    const symbol = symbol_table.referenceSymbol(reference_id);
    return if (symbol == .none) null else symbol;
}

fn nodeReferencesSymbol(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
    symbol: SymbolId,
) bool {
    if (index == .null) return false;
    const current = unwrapTransparent(tree, index);
    return referenceSymbol(symbol_table, current) == symbol;
}

fn transparentContains(tree: *const ast.Tree, wrapper: ast.NodeIndex, child: ast.NodeIndex) bool {
    return switch (tree.data(wrapper)) {
        .chain_expression => |expression| expression.expression == child,
        .parenthesized_expression => |expression| expression.expression == child,
        .ts_as_expression => |expression| expression.expression == child,
        .ts_satisfies_expression => |expression| expression.expression == child,
        .ts_non_null_expression => |expression| expression.expression == child,
        .ts_type_assertion => |expression| expression.expression == child,
        else => false,
    };
}

fn staticPropertyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (!computed) {
        return switch (tree.data(index)) {
            .identifier_name => |identifier| tree.string(identifier.name),
            else => null,
        };
    }
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        .template_literal => |literal| templateStringValue(tree, literal),
        else => null,
    };
}

fn templateStringValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;
    const quasis = tree.extra(literal.quasis);
    if (quasis.len != 1) return null;
    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
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
