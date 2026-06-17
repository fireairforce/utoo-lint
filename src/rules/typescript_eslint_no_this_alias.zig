const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-this-alias";

pub fn checkVariableDeclarator(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
    allowed_names: *const core.NoThisAliasAllowedNames,
) Allocator.Error!void {
    switch (tree.data(declarator.id)) {
        .binding_identifier => {},
        else => return,
    }

    if (!isThisExpression(tree, declarator.init)) return;

    try reportIfDisallowed(allocator, diagnostics, tree, declarator.id, allowed_names);
}

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    allowed_names: *const core.NoThisAliasAllowedNames,
) Allocator.Error!void {
    if (expression.operator != .assign) return;

    switch (tree.data(expression.left)) {
        .identifier_reference => {},
        else => return,
    }

    if (!isThisExpression(tree, expression.right)) return;

    try reportIfDisallowed(allocator, diagnostics, tree, expression.left, allowed_names);
}

fn reportIfDisallowed(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    target: ast.NodeIndex,
    allowed_names: *const core.NoThisAliasAllowedNames,
) Allocator.Error!void {
    if (isAllowedAlias(tree, target, allowed_names)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Unexpected aliasing of 'this' to local variable.",
        tree.span(target),
    );
}

fn isAllowedAlias(tree: *const ast.Tree, target: ast.NodeIndex, allowed_names: *const core.NoThisAliasAllowedNames) bool {
    const span = tree.span(target);
    if (span.end > tree.source.len or span.start > span.end) return false;
    return allowed_names.contains(tree.source[span.start..span.end]);
}

fn isThisExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .this_expression => true,
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
