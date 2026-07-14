const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const array_constructor_fix = @import("array_constructor_fix.zig");
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-array-constructor";

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (call.arguments.len == 1) return;
    if (call.type_arguments != .null) return;
    if (!isArrayIdentifier(tree, call.callee)) return;

    try addDiagnostic(allocator, diagnostics, tree, index, call.callee, call.arguments, call.optional, &ctx.path);
}

pub fn checkNewExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NewExpression,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (expression.arguments.len == 1) return;
    if (expression.type_arguments != .null) return;
    if (!isArrayIdentifier(tree, expression.callee)) return;

    try addDiagnostic(allocator, diagnostics, tree, index, expression.callee, expression.arguments, false, &ctx.path);
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    callee: ast.NodeIndex,
    arguments: ast.IndexRange,
    optional: bool,
    path: anytype,
) Allocator.Error!void {
    try array_constructor_fix.addDiagnostic(
        allocator,
        diagnostics,
        tree,
        index,
        callee,
        arguments,
        optional,
        array_constructor_fix.needsAsiGuard(tree, index, path),
        .{
            .allow_optional = true,
            .minimum_non_spread_when_nonempty = 0,
        },
        .@"error",
        id,
        "The array literal notation [] is preferable.",
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
