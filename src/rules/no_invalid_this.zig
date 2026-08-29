const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const semantic_compat = @import("../semantic_compat.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-invalid-this";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    scope_tree: semantic_compat.ScopeTree,
    symbol_table: semantic_compat.SymbolTable,
    cap_is_constructor: bool,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .scope_tree = scope_tree,
        .symbol_table = symbol_table,
        .cap_is_constructor = cap_is_constructor,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const ContextStack = struct {
    const capacity = 256;

    values: [capacity]bool = undefined,
    len: usize = 0,

    fn push(self: *ContextStack, valid: bool) void {
        if (self.len < capacity) self.values[self.len] = valid;
        self.len += 1;
    }

    fn pop(self: *ContextStack) void {
        if (self.len > 0) self.len -= 1;
    }

    fn current(self: *const ContextStack) bool {
        // Suppress diagnostics for pathological nesting beyond local storage.
        if (self.len == 0 or self.len > capacity) return true;
        return self.values[self.len - 1];
    }
};

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    scope_tree: semantic_compat.ScopeTree,
    symbol_table: semantic_compat.SymbolTable,
    cap_is_constructor: bool,
    contexts: ContextStack = .{},

    pub fn enter_program(
        self: *Visitor,
        _: ast.Program,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) traverser.Action {
        self.contexts.push(!ctx.tree.isModule());
        return .proceed;
    }

    pub fn exit_program(
        self: *Visitor,
        _: ast.Program,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) void {
        self.contexts.pop();
    }

    pub fn enter_function(
        self: *Visitor,
        function: ast.Function,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) traverser.Action {
        const scope = self.scope_tree.getScope(self.symbol_table.scopeOf(index));
        const valid = !scope.flags.strict or !isDefaultThisBinding(
            ctx.tree,
            function,
            index,
            ctx,
            self.cap_is_constructor,
        );
        self.contexts.push(valid);
        return .proceed;
    }

    pub fn exit_function(
        self: *Visitor,
        _: ast.Function,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) void {
        self.contexts.pop();
    }

    pub fn enter_arrow_function_expression(
        self: *Visitor,
        _: ast.ArrowFunctionExpression,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) traverser.Action {
        self.contexts.push(self.contexts.current());
        return .proceed;
    }

    pub fn exit_arrow_function_expression(
        self: *Visitor,
        _: ast.ArrowFunctionExpression,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) void {
        self.contexts.pop();
    }

    pub fn enter_static_block(
        self: *Visitor,
        _: ast.StaticBlock,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) traverser.Action {
        self.contexts.push(true);
        return .proceed;
    }

    pub fn exit_static_block(
        self: *Visitor,
        _: ast.StaticBlock,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) void {
        self.contexts.pop();
    }

    pub fn enter_this_expression(
        self: *Visitor,
        _: ast.ThisExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (!self.contexts.current()) {
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                "Unexpected 'this'.",
                ctx.tree.span(index),
            );
        }
        return .proceed;
    }

    pub fn exit_property_definition(
        self: *Visitor,
        _: ast.PropertyDefinition,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) void {
        self.contexts.pop();
    }

    pub fn exit_node(
        self: *Visitor,
        _: ast.NodeData,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) void {
        const parent_index = ctx.path.parent() orelse return;
        const property = switch (ctx.tree.data(parent_index)) {
            .property_definition => |property| property,
            else => return,
        };
        // Computed keys evaluate in the outer context. The initializer is an
        // implicit `this`-binding context, so start it only after the key.
        if (property.key == index) self.contexts.push(true);
    }
};

fn isDefaultThisBinding(
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    cap_is_constructor: bool,
) bool {
    if (hasExplicitThisParameter(tree, function.params)) return false;
    if (cap_is_constructor) {
        if (functionName(tree, function.id)) |name| {
            if (startsWithUpperCase(name)) return false;
        }
    }
    if (hasJSDocThisTag(tree, index)) return false;

    const is_anonymous = function.id == .null;
    var current = index;
    var depth: usize = 1;

    while (ctx.path.ancestor(depth)) |parent_index| {
        switch (tree.data(parent_index)) {
            .parenthesized_expression => |parenthesized| {
                if (parenthesized.expression != current) return true;
                current = parent_index;
                depth += 1;
            },
            .logical_expression, .conditional_expression => {
                current = parent_index;
                depth += 1;
            },
            .chain_expression => |chain| {
                if (chain.expression != current) return true;
                current = parent_index;
                depth += 1;
            },
            .return_statement => {
                const jump = returnedFromIife(tree, ctx, current, depth) orelse return true;
                current = jump.call;
                depth = jump.next_depth;
            },
            .arrow_function_expression => |arrow| {
                if (arrow.body != current) return true;
                const jump = calleeCallAbove(tree, ctx, parent_index, depth + 1) orelse return true;
                current = jump.call;
                depth = jump.next_depth;
            },
            .object_property => |property| return property.value != current,
            .property_definition => |property| return property.value != current,
            .method_definition => |method| return method.value != current,
            .assignment_expression => |assignment| {
                if (assignment.right != current) return true;
                if (isMemberExpression(tree, assignment.left)) return false;
                if (cap_is_constructor and is_anonymous) {
                    if (identifierName(tree, assignment.left)) |name| return !startsWithUpperCase(name);
                }
                return true;
            },
            .assignment_pattern => |assignment| {
                if (assignment.right != current) return true;
                if (isMemberExpression(tree, assignment.left)) return false;
                if (cap_is_constructor and is_anonymous) {
                    if (identifierName(tree, assignment.left)) |name| return !startsWithUpperCase(name);
                }
                return true;
            },
            .variable_declarator => |declarator| {
                if (declarator.init != current or !cap_is_constructor or !is_anonymous) return true;
                const name = bindingName(tree, declarator.id) orelse return true;
                return !startsWithUpperCase(name);
            },
            .member_expression => |member| {
                if (member.object != current or !isBindCallApply(tree, member)) return true;
                const jump = calleeCallAbove(tree, ctx, parent_index, depth + 1) orelse return true;
                const call = switch (tree.data(jump.call)) {
                    .call_expression => |call| call,
                    else => return true,
                };
                const arguments = tree.extra(call.arguments);
                return arguments.len < 1 or isNullOrUndefined(tree, arguments[0]);
            },
            .call_expression => |call| return isDefaultCallbackBinding(tree, call, current),
            else => return true,
        }
    }
    return true;
}

const IifeJump = struct {
    call: ast.NodeIndex,
    next_depth: usize,
};

fn returnedFromIife(
    tree: *const ast.Tree,
    ctx: *traverser.basic.Ctx,
    current: ast.NodeIndex,
    start_depth: usize,
) ?IifeJump {
    const statement = switch (tree.data(ctx.path.ancestor(start_depth).?)) {
        .return_statement => |statement| statement,
        else => return null,
    };
    if (statement.argument != current) return null;

    var depth = start_depth + 1;
    while (ctx.path.ancestor(depth)) |index| : (depth += 1) {
        switch (tree.data(index)) {
            .function => return calleeCallAbove(tree, ctx, index, depth + 1),
            .arrow_function_expression => return calleeCallAbove(tree, ctx, index, depth + 1),
            else => {},
        }
    }
    return null;
}

fn calleeCallAbove(
    tree: *const ast.Tree,
    ctx: *traverser.basic.Ctx,
    initial: ast.NodeIndex,
    start_depth: usize,
) ?IifeJump {
    var current = initial;
    var depth = start_depth;
    while (ctx.path.ancestor(depth)) |index| {
        switch (tree.data(index)) {
            .parenthesized_expression => |parenthesized| {
                if (parenthesized.expression != current) return null;
                current = index;
                depth += 1;
            },
            .chain_expression => |chain| {
                if (chain.expression != current) return null;
                current = index;
                depth += 1;
            },
            .call_expression => |call| {
                if (call.callee != current) return null;
                return .{ .call = index, .next_depth = depth + 1 };
            },
            else => return null,
        }
    }
    return null;
}

fn isDefaultCallbackBinding(tree: *const ast.Tree, call: ast.CallExpression, current: ast.NodeIndex) bool {
    const arguments = tree.extra(call.arguments);
    const callee = unwrapTransparent(tree, call.callee);
    const member = switch (tree.data(callee)) {
        .member_expression => |member| member,
        else => return true,
    };
    const method = memberName(tree, member) orelse return true;

    if (isIdentifierNamed(tree, member.object, "Reflect") and std.mem.eql(u8, method, "apply")) {
        return arguments.len != 3 or arguments[0] != current or isNullOrUndefined(tree, arguments[1]);
    }
    if (isArrayLikeName(identifierName(tree, unwrapTransparent(tree, member.object))) and
        (std.mem.eql(u8, method, "from") or std.mem.eql(u8, method, "fromAsync")))
    {
        return arguments.len != 3 or arguments[1] != current or isNullOrUndefined(tree, arguments[2]);
    }
    if (isArrayCallbackMethod(method)) {
        return arguments.len != 2 or arguments[0] != current or isNullOrUndefined(tree, arguments[1]);
    }
    return true;
}

fn hasExplicitThisParameter(tree: *const ast.Tree, params_index: ast.NodeIndex) bool {
    if (params_index == .null) return false;
    const params = switch (tree.data(params_index)) {
        .formal_parameters => |params| params,
        else => return false,
    };
    for (tree.extra(params.items)) |item| {
        const parameter = switch (tree.data(item)) {
            .formal_parameter => |parameter| parameter.pattern,
            else => item,
        };
        if (tree.data(parameter) == .ts_this_parameter) return true;
    }
    return false;
}

fn hasJSDocThisTag(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const function_start = tree.span(index).start;
    var cursor = function_start;
    var comment_index = tree.comments.len;
    while (comment_index > 0) {
        comment_index -= 1;
        const comment = tree.comments[comment_index];
        if (comment.span.end > cursor) continue;

        const gap = tree.source[comment.span.end..cursor];
        const trimmed = std.mem.trim(u8, gap, " \t\r\n");
        if (trimmed.len != 0 and !(cursor == function_start and std.mem.eql(u8, trimmed, "return"))) break;
        if (commentHasThisTag(tree.string(comment.value))) return true;
        cursor = comment.span.start;
    }
    return false;
}

fn commentHasThisTag(comment: []const u8) bool {
    var lines = std.mem.splitScalar(u8, comment, '\n');
    while (lines.next()) |line| {
        var text = std.mem.trimStart(u8, line, " \t\r");
        while (text.len > 0 and text[0] == '*') {
            text = std.mem.trimStart(u8, text[1..], " \t");
        }
        if (std.mem.startsWith(u8, text, "@this")) return true;
    }
    return false;
}

fn isBindCallApply(tree: *const ast.Tree, member: ast.MemberExpression) bool {
    const name = memberName(tree, member) orelse return false;
    return std.mem.eql(u8, name, "bind") or std.mem.eql(u8, name, "call") or std.mem.eql(u8, name, "apply");
}

fn isArrayCallbackMethod(name: []const u8) bool {
    const names = [_][]const u8{
        "every",   "filter",  "find", "findIndex", "findLast", "findLastIndex",
        "flatMap", "forEach", "map",  "some",
    };
    for (names) |candidate| if (std.mem.eql(u8, name, candidate)) return true;
    return false;
}

fn isArrayLikeName(name: ?[]const u8) bool {
    const value = name orelse return false;
    return std.mem.endsWith(u8, value, "Array");
}

fn isNullOrUndefined(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .null_literal => true,
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), "undefined"),
        .unary_expression => |unary| unary.operator == .void,
        else => false,
    };
}

fn isMemberExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return tree.data(unwrapTransparent(tree, index)) == .member_expression;
}

fn memberName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, member.property))) {
        .identifier_name => |identifier| if (member.computed) null else tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn isIdentifierNamed(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    const name = identifierName(tree, unwrapTransparent(tree, index)) orelse return false;
    return std.mem.eql(u8, name, expected);
}

fn identifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .binding_identifier => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn bindingName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn functionName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn startsWithUpperCase(name: []const u8) bool {
    if (name.len == 0) return false;
    return if (name[0] < 0x80) std.ascii.isUpper(name[0]) else true;
}

fn unwrapTransparent(tree: *const ast.Tree, initial: ast.NodeIndex) ast.NodeIndex {
    var index = initial;
    while (true) {
        index = switch (tree.data(index)) {
            .parenthesized_expression => |parenthesized| parenthesized.expression,
            .chain_expression => |chain| chain.expression,
            .ts_as_expression => |expression| expression.expression,
            .ts_satisfies_expression => |expression| expression.expression,
            .ts_type_assertion => |expression| expression.expression,
            .ts_non_null_expression => |expression| expression.expression,
            else => return index,
        };
    }
}
