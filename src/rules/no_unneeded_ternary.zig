const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-unneeded-ternary";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ConditionalExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    _ = booleanLiteralValue(tree, expression.consequent) orelse return;
    _ = booleanLiteralValue(tree, expression.alternate) orelse return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unnecessary use of boolean literals in conditional expression.",
        tree.span(index),
    );
}

fn booleanLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?bool {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .boolean_literal => |literal| literal.value,
        else => null,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;

    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |chain| current = chain.expression,
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            else => return current,
        }
    }

    return current;
}
