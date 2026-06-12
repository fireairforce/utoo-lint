const parser = @import("parser");
const core = @import("../core.zig");
const no_loss_of_precision = @import("no_loss_of_precision.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-loss-of-precision";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.NumericLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const raw = tree.string(literal.raw);
    if (!no_loss_of_precision.numericLiteralLosesPrecision(raw, literal.kind)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "This number literal will lose precision at runtime.",
        tree.span(index),
    );
}
