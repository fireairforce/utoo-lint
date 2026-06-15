const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

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
