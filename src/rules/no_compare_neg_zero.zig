const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-compare-neg-zero";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isComparisonOperator(expression.operator)) return;
    if (!isNegativeZero(tree, expression.left) and !isNegativeZero(tree, expression.right)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "Do not use the {s} operator to compare against -0.",
        .{expression.operator.toString()},
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

fn isNegativeZero(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    const unary = switch (tree.data(index)) {
        .unary_expression => |unary| unary,
        else => return false,
    };
    if (unary.operator != .negate) return false;

    return switch (tree.data(unary.argument)) {
        .numeric_literal => |literal| std.mem.eql(u8, tree.string(literal.raw), "0"),
        else => false,
    };
}
