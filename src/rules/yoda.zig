const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "yoda";

pub const Style = enum {
    never,
    always,
};

pub const Options = struct {
    style: Style = .never,
    only_equality: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkWithStyle(allocator, diagnostics, tree, expression, index, .never);
}

pub fn checkWithStyle(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
    style: Style,
) Allocator.Error!void {
    return checkWithOptions(allocator, diagnostics, tree, expression, index, .{ .style = style });
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (!isComparisonOperator(expression.operator)) return;
    if (options.only_equality and !isEqualityOperator(expression.operator)) return;

    const left_literal = isLiteralLike(tree, expression.left);
    const right_literal = isLiteralLike(tree, expression.right);
    if (hasExpectedYodaStyle(options.style, left_literal, right_literal)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        message(options.style),
        tree.span(index),
    );
}

fn hasExpectedYodaStyle(style: Style, left_literal: bool, right_literal: bool) bool {
    if (left_literal == right_literal) return true;

    return switch (style) {
        .never => !left_literal,
        .always => left_literal,
    };
}

fn message(style: Style) []const u8 {
    return switch (style) {
        .never => "Expected literal to be on the right side of comparison.",
        .always => "Expected literal to be on the left side of comparison.",
    };
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

fn isEqualityOperator(operator: ast.BinaryOperator) bool {
    return switch (operator) {
        .equal,
        .not_equal,
        .strict_equal,
        .strict_not_equal,
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
