const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-empty-pattern";

pub fn checkObjectPattern(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    pattern: ast.ObjectPattern,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (pattern.properties.len > 0 or pattern.rest != .null) return;

    try addDiagnostic(allocator, diagnostics, tree, index, "object");
}

pub fn checkArrayPattern(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    pattern: ast.ArrayPattern,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (pattern.elements.len > 0 or pattern.rest != .null) return;

    try addDiagnostic(allocator, diagnostics, tree, index, "array");
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    pattern_type: []const u8,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Unexpected empty {s} pattern.",
        .{pattern_type},
    );
}
