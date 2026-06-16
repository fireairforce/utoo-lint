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

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Use strict equality operators.",
        tree.span(index),
    );
}

fn isNullLiteral(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .null_literal => true,
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
