const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-self-compare";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isComparisonOperator(expression.operator)) return;
    if (!sameSource(tree, expression.left, expression.right)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Do not compare a value to itself.",
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

fn sameSource(tree: *const ast.Tree, left: ast.NodeIndex, right: ast.NodeIndex) bool {
    if (left == .null or right == .null) return false;

    const left_span = tree.span(unwrapTransparent(tree, left));
    const right_span = tree.span(unwrapTransparent(tree, right));

    const left_start: usize = @intCast(left_span.start);
    const left_end: usize = @intCast(left_span.end);
    const right_start: usize = @intCast(right_span.start);
    const right_end: usize = @intCast(right_span.end);

    if (left_start >= left_end or right_start >= right_end) return false;
    if (left_end > tree.source.len or right_end > tree.source.len) return false;

    return std.mem.eql(u8, tree.source[left_start..left_end], tree.source[right_start..right_end]);
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
