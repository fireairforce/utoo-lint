const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-void";

pub const Options = struct {
    allow_as_statement: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.UnaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkWithOptions(allocator, diagnostics, tree, expression, index, null, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.UnaryExpression,
    index: ast.NodeIndex,
    parent: ?ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (expression.operator != .void) return;
    if (options.allow_as_statement and isExpressionStatementParent(tree, index, parent)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "The use of void is not allowed.",
        tree.span(index),
    );
}

fn isExpressionStatementParent(tree: *const ast.Tree, index: ast.NodeIndex, parent: ?ast.NodeIndex) bool {
    const parent_index = parent orelse return false;
    return switch (tree.data(parent_index)) {
        .expression_statement => |statement| statement.expression == index,
        else => false,
    };
}
