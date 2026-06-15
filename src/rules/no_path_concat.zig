const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-path-concat";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (expression.operator != .add) return;
    if (!isPathConcat(tree, expression.left, expression.right)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Use path.join() or path.resolve() instead of path string concatenation.",
        tree.span(index),
    );
}

fn isPathConcat(tree: *const ast.Tree, left: ast.NodeIndex, right: ast.NodeIndex) bool {
    return (isPathMetaIdentifier(tree, left) and isStringLikePathPart(tree, right)) or
        (isPathMetaIdentifier(tree, right) and isStringLikePathPart(tree, left));
}

fn isPathMetaIdentifier(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| {
            const name = tree.string(identifier.name);
            return std.mem.eql(u8, name, "__dirname") or std.mem.eql(u8, name, "__filename");
        },
        else => false,
    };
}

fn isStringLikePathPart(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .string_literal,
        .template_literal,
        => true,
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
