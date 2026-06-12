const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-unnecessary-type-constraint";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    parameter: ast.TSTypeParameter,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const constraint = unnecessaryConstraint(tree, parameter.constraint) orelse return;
    const name = typeParameterName(tree, parameter.name) orelse return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "Constraining the generic type `{s}` to `{s}` does nothing and is unnecessary.",
        .{ name, constraint },
    );
}

fn unnecessaryConstraint(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .ts_any_keyword => "any",
        .ts_unknown_keyword => "unknown",
        else => null,
    };
}

fn typeParameterName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}
