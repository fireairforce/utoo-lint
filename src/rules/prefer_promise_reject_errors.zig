const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "prefer-promise-reject-errors";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (isGlobalPromiseRejectCall(ctx.tree, self.symbol_table, call)) {
            try checkRejectArgument(self.allocator, self.diagnostics, ctx.tree, call.arguments, index);
        }

        return .proceed;
    }

    pub fn enter_new_expression(
        self: *Visitor,
        expression: ast.NewExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (!isGlobalPromiseReference(ctx.tree, self.symbol_table, expression.callee)) return .proceed;
        const executor = promiseExecutor(ctx.tree, expression.arguments) orelse return .proceed;
        const reject_name = executorRejectName(ctx.tree, executor) orelse return .proceed;

        try scanExecutor(self.allocator, self.diagnostics, ctx.tree, reject_name, executor);
        return .proceed;
    }
};

fn isGlobalPromiseRejectCall(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    call: ast.CallExpression,
) bool {
    if (call.optional) return false;

    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.optional or member.computed) return false;

    if (!isIdentifierNameNamed(tree, member.property, "reject")) return false;
    return isGlobalPromiseReference(tree, symbol_table, member.object);
}

fn promiseExecutor(tree: *const ast.Tree, arguments: ast.IndexRange) ?ast.NodeIndex {
    if (arguments.len == 0) return null;

    const executor = unwrapTransparent(tree, tree.extra(arguments)[0]);
    return switch (tree.data(executor)) {
        .arrow_function_expression,
        .function,
        => executor,
        else => null,
    };
}

fn executorRejectName(tree: *const ast.Tree, executor: ast.NodeIndex) ?[]const u8 {
    const params_index = switch (tree.data(executor)) {
        .function => |function| function.params,
        .arrow_function_expression => |arrow| arrow.params,
        else => return null,
    };

    const params = switch (tree.data(params_index)) {
        .formal_parameters => |params| params,
        else => return null,
    };

    const items = tree.extra(params.items);
    if (items.len < 2) return null;

    const second = switch (tree.data(items[1])) {
        .formal_parameter => |parameter| parameter.pattern,
        else => return null,
    };

    return bindingIdentifierName(tree, second);
}

fn scanExecutor(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    reject_name: []const u8,
    executor: ast.NodeIndex,
) Allocator.Error!void {
    switch (tree.data(executor)) {
        .function => |function| try scanNode(allocator, diagnostics, tree, reject_name, function.body),
        .arrow_function_expression => |arrow| try scanNode(allocator, diagnostics, tree, reject_name, arrow.body),
        else => {},
    }
}

fn scanNode(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    reject_name: []const u8,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(index)) {
        .call_expression => |call| {
            if (isRejectCall(tree, reject_name, call)) {
                try checkRejectArgument(allocator, diagnostics, tree, call.arguments, index);
            }
            try scanChildren(allocator, diagnostics, tree, reject_name, call);
        },
        .function,
        .arrow_function_expression,
        .class,
        => return,
        inline else => |node| try scanChildren(allocator, diagnostics, tree, reject_name, node),
    }
}

fn scanChildren(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    reject_name: []const u8,
    node: anytype,
) Allocator.Error!void {
    const T = @TypeOf(node);
    if (@typeInfo(T) != .@"struct") return;

    inline for (@typeInfo(T).@"struct".fields) |field| {
        if (field.type == ast.NodeIndex) {
            try scanNode(allocator, diagnostics, tree, reject_name, @field(node, field.name));
        } else if (field.type == ast.IndexRange) {
            for (tree.extra(@field(node, field.name))) |child| {
                try scanNode(allocator, diagnostics, tree, reject_name, child);
            }
        }
    }
}

fn isRejectCall(tree: *const ast.Tree, reject_name: []const u8, call: ast.CallExpression) bool {
    if (call.optional) return false;
    return isIdentifierReferenceNamed(tree, call.callee, reject_name);
}

fn checkRejectArgument(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    arguments: ast.IndexRange,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (arguments.len == 0) return;
    const argument = tree.extra(arguments)[0];
    if (!isInvalidRejectReason(tree, unwrapTransparent(tree, argument))) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Expected the Promise rejection reason to be an Error.",
        tree.span(index),
    );
}

fn isInvalidRejectReason(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .string_literal,
        .numeric_literal,
        .bigint_literal,
        .boolean_literal,
        .null_literal,
        .template_literal,
        => true,
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), "undefined"),
        .binary_expression => |expression| expression.operator == .add,
        else => false,
    };
}

fn isGlobalPromiseReference(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) bool {
    const unwrapped = unwrapTransparent(tree, index);
    if (!isIdentifierReferenceNamed(tree, unwrapped, "Promise")) return false;
    return isUnresolvedReference(symbol_table, unwrapped);
}

fn isUnresolvedReference(
    symbol_table: traverser.semantic.SymbolTable,
    node: ast.NodeIndex,
) bool {
    var iter = symbol_table.iterReferences();
    while (iter.next()) |entry| {
        if (entry.reference.node == node) {
            return symbol_table.referenceSymbol(entry.id) == .none;
        }
    }

    return false;
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    if (index == .null) return false;
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
    };
}

fn isIdentifierNameNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    if (index == .null) return false;
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_name => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;

    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |chain| current = chain.expression,
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            else => return current,
        }
    }

    return current;
}
