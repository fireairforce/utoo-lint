const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-confusing-arrow";

pub const Options = struct {
    allow_parens: bool = true,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ArrowFunctionExpression,
) Allocator.Error!void {
    try checkWithOptions(allocator, diagnostics, tree, expression, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ArrowFunctionExpression,
    options: Options,
) Allocator.Error!void {
    if (!expression.expression) return;

    if (!isConfusingBody(tree, expression.body, options.allow_parens)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Arrow function used ambiguously with a conditional expression.",
        tree.span(expression.body),
    );
}

fn isConfusingBody(tree: *const ast.Tree, index: ast.NodeIndex, allow_parens: bool) bool {
    switch (tree.data(index)) {
        .conditional_expression => return true,
        .parenthesized_expression => |parenthesized| {
            if (allow_parens) return false;
            return tree.data(parenthesized.expression) == .conditional_expression;
        },
        else => return false,
    }
}
