const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "use-isnan";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isEqualityOperator(expression.operator)) return;
    if (!isNaNReference(tree, expression.left) and !isNaNReference(tree, expression.right)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Use Number.isNaN or isNaN to compare with NaN.",
        tree.span(index),
    );
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

fn isNaNReference(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), "NaN"),
        .chain_expression => |chain| isNaNReference(tree, chain.expression),
        .parenthesized_expression => |parenthesized| isNaNReference(tree, parenthesized.expression),
        else => false,
    };
}
