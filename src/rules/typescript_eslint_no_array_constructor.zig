const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-array-constructor";

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (call.arguments.len == 1) return;
    if (call.type_arguments != .null) return;
    if (!isArrayIdentifier(tree, call.callee)) return;

    try addDiagnostic(allocator, diagnostics, tree, index);
}

pub fn checkNewExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NewExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (expression.arguments.len == 1) return;
    if (expression.type_arguments != .null) return;
    if (!isArrayIdentifier(tree, expression.callee)) return;

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
        .@"error",
        id,
        "The array literal notation [] is preferable.",
        tree.span(index),
    );
}

fn isArrayIdentifier(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    const name = switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => return false,
    };
    return std.mem.eql(u8, name, "Array");
}
