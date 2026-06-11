const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-sparse-arrays";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ArrayExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!hasHole(tree, expression.elements)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected sparse array.",
        tree.span(index),
    );
}

fn hasHole(tree: *const ast.Tree, elements: ast.IndexRange) bool {
    for (tree.extra(elements)) |element| {
        if (element == .null) return true;
    }

    return false;
}
