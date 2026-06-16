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
    const holes = countHoles(tree, expression.elements);
    if (holes == 0) return;

    for (0..holes) |_| {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Unexpected sparse array.",
            tree.span(index),
        );
    }
}

fn countHoles(tree: *const ast.Tree, elements: ast.IndexRange) usize {
    var holes: usize = 0;
    for (tree.extra(elements)) |element| {
        if (element == .null) holes += 1;
    }

    return holes;
}
