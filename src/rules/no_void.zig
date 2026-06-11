const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-void";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.UnaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (expression.operator != .void) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "The use of void is not allowed.",
        tree.span(index),
    );
}
