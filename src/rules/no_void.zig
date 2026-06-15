const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
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
    path: ?*const traverser.NodePath,
    options: Options,
) Allocator.Error!void {
    if (expression.operator != .void) return;
    if (options.allow_as_statement and isExpressionStatementUse(tree, index, path)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "The use of void is not allowed.",
        tree.span(index),
    );
}

fn isExpressionStatementUse(
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    path: ?*const traverser.NodePath,
) bool {
    const node_path = path orelse return false;
    var current = index;
    var depth: usize = 1;

    while (node_path.ancestor(depth)) |parent| : (depth += 1) {
        switch (tree.data(parent)) {
            .parenthesized_expression => |expression| {
                if (expression.expression != current) return false;
                current = parent;
            },
            .expression_statement => |statement| return statement.expression == current,
            else => return false,
        }
    }

    return false;
}
