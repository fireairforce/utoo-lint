const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-bitwise";

pub const Options = struct {
    allow_bitwise_and: bool = false,
    allow_bitwise_or: bool = false,
    allow_bitwise_xor: bool = false,
    allow_bitwise_not: bool = false,
    allow_left_shift: bool = false,
    allow_right_shift: bool = false,
    allow_unsigned_right_shift: bool = false,
    int32_hint: bool = false,
};

pub fn checkBinaryExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    return checkBinaryExpressionWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkBinaryExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (!isBitwiseBinaryOperator(expression.operator)) return;
    if (allowsBinaryOperator(options, expression.operator)) return;
    if (options.int32_hint and isInt32Hint(tree, expression)) return;
    try addDiagnostic(allocator, diagnostics, tree, index);
}

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    return checkAssignmentExpressionWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkAssignmentExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (!isBitwiseAssignmentOperator(expression.operator)) return;
    if (allowsAssignmentOperator(options, expression.operator)) return;
    try addDiagnostic(allocator, diagnostics, tree, index);
}

pub fn checkUnaryExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.UnaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    return checkUnaryExpressionWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkUnaryExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.UnaryExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (expression.operator != .bitwise_not) return;
    if (options.allow_bitwise_not) return;
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

fn allowsBinaryOperator(options: Options, operator: ast.BinaryOperator) bool {
    return switch (operator) {
        .bitwise_or => options.allow_bitwise_or,
        .bitwise_xor => options.allow_bitwise_xor,
        .bitwise_and => options.allow_bitwise_and,
        .left_shift => options.allow_left_shift,
        .right_shift => options.allow_right_shift,
        .unsigned_right_shift => options.allow_unsigned_right_shift,
        else => false,
    };
}

fn allowsAssignmentOperator(options: Options, operator: ast.AssignmentOperator) bool {
    return switch (operator) {
        .bitwise_or_assign => options.allow_bitwise_or,
        .bitwise_xor_assign => options.allow_bitwise_xor,
        .bitwise_and_assign => options.allow_bitwise_and,
        .left_shift_assign => options.allow_left_shift,
        .right_shift_assign => options.allow_right_shift,
        .unsigned_right_shift_assign => options.allow_unsigned_right_shift,
        else => false,
    };
}

fn isInt32Hint(tree: *const ast.Tree, expression: ast.BinaryExpression) bool {
    if (expression.operator != .bitwise_or) return false;
    return isNumericZero(tree, expression.right);
}

fn isNumericZero(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .numeric_literal => |literal| literal.value(tree) == 0,
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
