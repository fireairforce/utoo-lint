const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-unused-expressions";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ExpressionStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (hasSideEffect(tree, statement.expression)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Expected an assignment or function call and instead saw an expression.",
        tree.span(index),
    );
}

fn hasSideEffect(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .assignment_expression,
        .await_expression,
        .call_expression,
        .import_expression,
        .new_expression,
        .tagged_template_expression,
        .update_expression,
        .yield_expression,
        => true,

        .chain_expression => |chain| hasSideEffect(tree, chain.expression),
        .parenthesized_expression => |parenthesized| hasSideEffect(tree, parenthesized.expression),
        .sequence_expression => |sequence| hasLastExpressionSideEffect(tree, sequence),

        else => false,
    };
}

fn hasLastExpressionSideEffect(tree: *const ast.Tree, sequence: ast.SequenceExpression) bool {
    const expressions = tree.extra(sequence.expressions);
    if (expressions.len == 0) return false;

    return hasSideEffect(tree, expressions[expressions.len - 1]);
}
