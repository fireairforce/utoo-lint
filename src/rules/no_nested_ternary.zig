const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-nested-ternary";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ConditionalExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!hasNestedTernary(tree, expression)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Nested ternary expressions are not allowed.",
        tree.span(index),
    );
}

fn hasNestedTernary(tree: *const ast.Tree, expression: ast.ConditionalExpression) bool {
    return isConditionalExpression(tree, expression.@"test") or
        isConditionalExpression(tree, expression.consequent) or
        isConditionalExpression(tree, expression.alternate);
}

fn isConditionalExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .conditional_expression => true,
        else => false,
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
