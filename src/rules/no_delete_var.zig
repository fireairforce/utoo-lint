const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-delete-var";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.UnaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (expression.operator != .delete) return;
    if (!isIdentifierReference(tree, expression.argument)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Do not delete variables.",
        tree.span(index),
    );
}

fn isIdentifierReference(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .identifier_reference => true,
        else => false,
    };
}
