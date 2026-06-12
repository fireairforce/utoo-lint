const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-extra-non-null-assertion";

pub fn checkNonNullExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.TSNonNullExpression,
) Allocator.Error!void {
    if (!isNonNullExpression(tree, expression.expression)) return;
    try addDiagnostic(allocator, diagnostics, tree, expression.expression);
}

pub fn checkMemberExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.MemberExpression,
) Allocator.Error!void {
    if (!expression.optional) return;
    if (!isNonNullExpression(tree, expression.object)) return;
    try addDiagnostic(allocator, diagnostics, tree, expression.object);
}

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.CallExpression,
) Allocator.Error!void {
    if (!expression.optional) return;
    if (!isNonNullExpression(tree, expression.callee)) return;
    try addDiagnostic(allocator, diagnostics, tree, expression.callee);
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
        .@"error",
        id,
        "Forbidden extra non-null assertion.",
        tree.span(index),
    );
}

fn isNonNullExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .ts_non_null_expression => true,
        else => false,
    };
}
