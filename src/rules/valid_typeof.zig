const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "valid-typeof";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isTypeofComparisonOperator(expression.operator)) return;

    const left_typeof = isTypeofExpression(tree, expression.left);
    const right_typeof = isTypeofExpression(tree, expression.right);
    if (left_typeof == right_typeof) return;

    const literal_index = if (left_typeof) expression.right else expression.left;
    const value = stringLiteralValue(tree, literal_index) orelse return;
    if (isValidTypeofValue(value)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Invalid typeof comparison value.",
        tree.span(index),
    );
}

fn isTypeofComparisonOperator(operator: ast.BinaryOperator) bool {
    return switch (operator) {
        .equal,
        .not_equal,
        .strict_equal,
        .strict_not_equal,
        => true,
        else => false,
    };
}

fn isTypeofExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .unary_expression => |unary| unary.operator == .typeof,
        else => false,
    };
}

fn stringLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn isValidTypeofValue(value: []const u8) bool {
    return std.mem.eql(u8, value, "undefined") or
        std.mem.eql(u8, value, "object") or
        std.mem.eql(u8, value, "boolean") or
        std.mem.eql(u8, value, "number") or
        std.mem.eql(u8, value, "string") or
        std.mem.eql(u8, value, "function") or
        std.mem.eql(u8, value, "symbol") or
        std.mem.eql(u8, value, "bigint");
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
