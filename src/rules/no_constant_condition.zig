const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-constant-condition";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NodeIndex,
) Allocator.Error!void {
    const unwrapped = unwrapTransparent(tree, expression);
    if (!isConstantExpression(tree, unwrapped)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected constant condition.",
        tree.span(unwrapped),
    );
}

pub fn checkWhile(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NodeIndex,
) Allocator.Error!void {
    const unwrapped = unwrapTransparent(tree, expression);
    if (isBooleanTrue(tree, unwrapped)) return;

    try check(allocator, diagnostics, tree, expression);
}

fn isConstantExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .boolean_literal,
        .null_literal,
        .numeric_literal,
        .bigint_literal,
        .string_literal,
        .regexp_literal,
        .array_expression,
        .object_expression,
        .arrow_function_expression,
        => true,
        .template_literal => |literal| literal.expressions.len == 0,
        .function => |function| function.type == .function_expression or function.type == .ts_empty_body_function_expression,
        .class => |class| class.type == .class_expression,
        .unary_expression => |unary| isConstantUnaryExpression(tree, unary),
        .logical_expression => |logical| isConstantLogicalExpression(tree, logical),
        else => false,
    };
}

fn isBooleanTrue(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .boolean_literal => |literal| literal.value,
        else => false,
    };
}

fn isConstantUnaryExpression(tree: *const ast.Tree, unary: ast.UnaryExpression) bool {
    const argument = unwrapTransparent(tree, unary.argument);
    return switch (unary.operator) {
        .logical_not,
        .positive,
        .negate,
        .bitwise_not,
        => isConstantExpression(tree, argument),
        .void => true,
        .typeof,
        .delete,
        => false,
    };
}

fn isConstantLogicalExpression(tree: *const ast.Tree, logical: ast.LogicalExpression) bool {
    if (logical.operator == .nullish_coalescing) return false;

    const left = staticTruthiness(tree, unwrapTransparent(tree, logical.left));
    const right = staticTruthiness(tree, unwrapTransparent(tree, logical.right));

    return switch (logical.operator) {
        .@"or" => (left orelse false) or (right orelse false) or (left != null and right != null),
        .@"and" => (left != null and !left.?) or (right != null and !right.?) or (left != null and right != null),
        .nullish_coalescing => false,
    };
}

fn staticTruthiness(tree: *const ast.Tree, index: ast.NodeIndex) ?bool {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .boolean_literal => |literal| literal.value,
        .null_literal => false,
        .numeric_literal => |literal| {
            const value = literal.value(tree);
            return value != 0 and value == value;
        },
        .bigint_literal => |literal| bigintTruthy(tree.string(literal.raw)),
        .string_literal => |literal| tree.string(literal.value).len != 0,
        .regexp_literal,
        .array_expression,
        .object_expression,
        .arrow_function_expression,
        => true,
        .template_literal => |literal| templateLiteralTruthy(tree, literal),
        .function => |function| if (function.type == .function_expression or function.type == .ts_empty_body_function_expression) true else null,
        .class => |class| if (class.type == .class_expression) true else null,
        .unary_expression => |unary| staticUnaryTruthiness(tree, unary),
        else => null,
    };
}

fn staticUnaryTruthiness(tree: *const ast.Tree, unary: ast.UnaryExpression) ?bool {
    const argument = unwrapTransparent(tree, unary.argument);
    return switch (unary.operator) {
        .logical_not => if (staticTruthiness(tree, argument)) |truthy| !truthy else null,
        .positive,
        .negate,
        => switch (tree.data(argument)) {
            .numeric_literal => staticTruthiness(tree, argument),
            else => null,
        },
        .bitwise_not => null,
        .void => false,
        .typeof,
        .delete,
        => null,
    };
}

fn templateLiteralTruthy(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?bool {
    if (literal.expressions.len != 0) return null;

    const quasis = tree.extra(literal.quasis);
    if (quasis.len != 1) return null;

    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked).len != 0,
        else => null,
    };
}

fn bigintTruthy(raw: []const u8) bool {
    for (raw) |char| {
        if (char == '_' or char == 'n') continue;
        if (char != '0') return true;
    }
    return false;
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
