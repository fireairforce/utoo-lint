const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-octal";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.NumericLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isLegacyOctal(tree, literal)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Octal literals should not be used.",
        tree.span(index),
    );
}

fn isLegacyOctal(tree: *const ast.Tree, literal: ast.NumericLiteral) bool {
    if (literal.kind != .octal) return false;

    const raw = tree.string(literal.raw);
    if (raw.len < 2) return false;

    return !std.mem.startsWith(u8, raw, "0o") and
        !std.mem.startsWith(u8, raw, "0O");
}
