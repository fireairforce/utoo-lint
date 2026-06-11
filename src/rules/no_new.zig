const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-new";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    parent: ast.NodeIndex,
) Allocator.Error!void {
    if (tree.data(parent) != .expression_statement) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Do not use 'new' for side effects.",
        tree.span(index),
    );
}
