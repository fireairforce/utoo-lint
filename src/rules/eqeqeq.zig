const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "eqeqeq";

pub const Options = struct {
    style: core.EqeqeqStyle = .strict,
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
    if (expression.operator != .equal and expression.operator != .not_equal) return;
    if (options.style == .allow_null and
        (isNullLiteral(tree, expression.left) or isNullLiteral(tree, expression.right)))
    {
        return;
    }
    if (options.style == .smart and isSmartException(tree, expression)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Use strict equality operators.",
        tree.span(index),
    );
}

fn isSmartException(tree: *const ast.Tree, expression: ast.BinaryExpression) bool {
    if (isNullLiteral(tree, expression.left) or isNullLiteral(tree, expression.right)) return true;
    if (isTypeofExpression(tree, expression.left) or isTypeofExpression(tree, expression.right)) return true;
    const left_kind = literalKind(tree, expression.left) orelse return false;
    const right_kind = literalKind(tree, expression.right) orelse return false;
    return left_kind == right_kind;
}

fn isNullLiteral(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .null_literal => true,
        else => false,
    };
}

fn isTypeofExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .unary_expression => |unary| unary.operator == .typeof,
        else => false,
    };
}

const LiteralKind = enum {
    bigint,
    boolean,
    null,
    number,
    object,
    string,
};

fn literalKind(tree: *const ast.Tree, index: ast.NodeIndex) ?LiteralKind {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .bigint_literal => .bigint,
        .boolean_literal => .boolean,
        .null_literal => .null,
        .numeric_literal => .number,
        .regexp_literal => .object,
        .string_literal => .string,
        else => null,
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
