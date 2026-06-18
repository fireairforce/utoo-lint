const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-unsafe-negation";

pub const Options = struct {
    enforce_for_ordering_relations: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    return checkWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (!isUnsafeOperator(expression.operator, options)) return;
    if (!isLogicalNot(tree, expression.left)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "The negation operator is used unsafely on the left side of this binary expression.",
        tree.span(index),
    );
}

fn isUnsafeOperator(operator: ast.BinaryOperator, options: Options) bool {
    return switch (operator) {
        .in,
        .instanceof,
        => true,
        .less_than,
        .less_than_or_equal,
        .greater_than,
        .greater_than_or_equal,
        => options.enforce_for_ordering_relations,
        else => false,
    };
}

fn isLogicalNot(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .unary_expression => |unary| unary.operator == .logical_not,
        else => false,
    };
}
