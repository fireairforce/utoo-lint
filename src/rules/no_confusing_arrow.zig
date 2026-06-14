const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-confusing-arrow";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ArrowFunctionExpression,
) Allocator.Error!void {
    if (!expression.expression) return;

    switch (tree.data(expression.body)) {
        .conditional_expression => {},
        else => return,
    }

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Arrow function used ambiguously with a conditional expression.",
        tree.span(expression.body),
    );
}
