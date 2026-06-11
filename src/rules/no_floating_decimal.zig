const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-floating-decimal";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.NumericLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const raw = tree.string(literal.raw);
    if (!hasFloatingDecimal(raw)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "A leading or trailing decimal point should include a digit.",
        tree.span(index),
    );
}

fn hasFloatingDecimal(raw: []const u8) bool {
    if (raw.len == 0) return false;

    if (raw[0] == '.') return raw.len > 1 and std.ascii.isDigit(raw[1]);
    if (raw[raw.len - 1] == '.') return raw.len > 1 and std.ascii.isDigit(raw[raw.len - 2]);
    return false;
}
