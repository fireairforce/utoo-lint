const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-bitwise";

pub fn checkBinaryExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isBitwiseBinaryOperator(expression.operator)) return;
    try addDiagnostic(allocator, diagnostics, tree, index);
}

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isBitwiseAssignmentOperator(expression.operator)) return;
    try addDiagnostic(allocator, diagnostics, tree, index);
}

pub fn checkUnaryExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.UnaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (expression.operator != .bitwise_not) return;
    try addDiagnostic(allocator, diagnostics, tree, index);
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
        "Unexpected use of bitwise operator.",
        tree.span(index),
    );
}

fn isBitwiseBinaryOperator(operator: ast.BinaryOperator) bool {
    return switch (operator) {
        .bitwise_or,
        .bitwise_xor,
        .bitwise_and,
        .left_shift,
        .right_shift,
        .unsigned_right_shift,
        => true,
        else => false,
    };
}

fn isBitwiseAssignmentOperator(operator: ast.AssignmentOperator) bool {
    return switch (operator) {
        .left_shift_assign,
        .right_shift_assign,
        .unsigned_right_shift_assign,
        .bitwise_or_assign,
        .bitwise_xor_assign,
        .bitwise_and_assign,
        => true,
        else => false,
    };
}
