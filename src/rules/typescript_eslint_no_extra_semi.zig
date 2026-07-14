const parser = @import("parser");
const core = @import("../core.zig");
const no_extra_semi = @import("no_extra_semi.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-extra-semi";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (no_extra_semi.isStatementBody(tree, index, ctx)) return;

    const span = tree.span(index);
    try core.addDiagnosticWithFix(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Unnecessary semicolon.",
        span,
        .{ .span = span, .replacement = "" },
    );
}
