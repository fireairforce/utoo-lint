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
    allow_destructuring: bool,
) Allocator.Error!void {
    switch (tree.data(declarator.id)) {
        .binding_identifier => {
            if (!isThisExpression(tree, declarator.init)) return;
            try reportIfDisallowed(allocator, diagnostics, tree, declarator.id, allowed_names);
        },
        .array_pattern, .object_pattern => {
            if (allow_destructuring or !isThisExpression(tree, declarator.init)) return;
            try report(allocator, diagnostics, tree, declarator.id);
        },
        else => return,
    }
}

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    allowed_names: *const core.NoThisAliasAllowedNames,
    allow_destructuring: bool,
) Allocator.Error!void {
    if (expression.operator != .assign) return;

    switch (tree.data(expression.left)) {
        .identifier_reference => {
            if (!isThisExpression(tree, expression.right)) return;
            try reportIfDisallowed(allocator, diagnostics, tree, expression.left, allowed_names);
        },
        .array_pattern, .object_pattern => {
            if (allow_destructuring or !isThisExpression(tree, expression.right)) return;
            try report(allocator, diagnostics, tree, expression.left);
        },
        else => return,
    }
}

fn reportIfDisallowed(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    target: ast.NodeIndex,
    allowed_names: *const core.NoThisAliasAllowedNames,
) Allocator.Error!void {
    if (isAllowedAlias(tree, target, allowed_names)) return;

    try report(allocator, diagnostics, tree, target);
}

fn report(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    target: ast.NodeIndex,
) Allocator.Error!void {
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
