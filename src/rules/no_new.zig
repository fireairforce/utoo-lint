const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-new";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    path: *const traverser.NodePath,
) Allocator.Error!void {
    if (!isExpressionStatementUse(tree, index, path)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Do not use 'new' for side effects.",
        tree.span(index),
    );
}

fn isExpressionStatementUse(
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    path: *const traverser.NodePath,
) bool {
    var current = index;
    var depth: usize = 1;

    while (path.ancestor(depth)) |parent| : (depth += 1) {
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
