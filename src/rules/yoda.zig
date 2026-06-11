const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "yoda";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isComparisonOperator(expression.operator)) return;
    if (!isLiteralLike(tree, expression.left) or isLiteralLike(tree, expression.right)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Expected literal to be on the right side of comparison.",
        tree.span(index),
    );
}

fn isComparisonOperator(operator: ast.BinaryOperator) bool {
    return switch (operator) {
        .equal,
        .not_equal,
        .strict_equal,
        .strict_not_equal,
        .less_than,
        .less_than_or_equal,
        .greater_than,
        .greater_than_or_equal,
        => true,
        else => false,
    };
}

fn isLiteralLike(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .string_literal,
        .numeric_literal,
        .boolean_literal,
        .null_literal,
        .bigint_literal,
        .regexp_literal,
        => true,
        .template_literal => |literal| literal.expressions.len == 0,
        .unary_expression => |expression| isNegativeNumericLiteral(tree, expression),
        else => false,
    };
}

fn isNegativeNumericLiteral(tree: *const ast.Tree, expression: ast.UnaryExpression) bool {
    if (expression.operator != .negate) return false;

    return switch (tree.data(unwrapTransparent(tree, expression.argument))) {
        .numeric_literal => true,
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
