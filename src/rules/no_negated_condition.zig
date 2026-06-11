const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-negated-condition";

pub fn checkIfStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.IfStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!hasElseWithoutCondition(tree, statement)) return;
    if (!isNegatedCondition(tree, statement.@"test")) return;

    try addDiagnostic(allocator, diagnostics, tree, index);
}

pub fn checkConditionalExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ConditionalExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isNegatedCondition(tree, expression.@"test")) return;

    try addDiagnostic(allocator, diagnostics, tree, index);
}

fn hasElseWithoutCondition(tree: *const ast.Tree, statement: ast.IfStatement) bool {
    if (statement.alternate == .null) return false;

    return switch (tree.data(statement.alternate)) {
        .if_statement => false,
        else => true,
    };
}

fn isNegatedCondition(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .unary_expression => |expression| expression.operator == .logical_not,
        .binary_expression => |expression| expression.operator == .not_equal or expression.operator == .strict_not_equal,
        else => false,
    };
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected negated condition.",
        tree.span(index),
    );
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
