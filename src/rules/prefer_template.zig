const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "prefer-template";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (expression.operator != .add) return;

    const left_static_string = isStaticStringLike(tree, expression.left);
    const right_static_string = isStaticStringLike(tree, expression.right);
    if (!left_static_string and !right_static_string) return;
    if (left_static_string and right_static_string) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Use a template literal instead of string concatenation.",
        tree.span(index),
    );
}

fn isStaticStringLike(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .string_literal => true,
        .template_literal => true,
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
