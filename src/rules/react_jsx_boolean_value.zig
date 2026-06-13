const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/jsx-boolean-value";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    attribute: ast.JSXAttribute,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const name = attributeName(tree, attribute.name) orelse return;
    if (!isExplicitTrue(tree, attribute.value)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "Value must be omitted for boolean attribute `{s}`",
        .{name},
    );
}

fn attributeName(tree: *const ast.Tree, name_index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isExplicitTrue(tree: *const ast.Tree, value_index: ast.NodeIndex) bool {
    if (value_index == .null) return false;

    const container = switch (tree.data(value_index)) {
        .jsx_expression_container => |container| container,
        else => return false,
    };

    return switch (tree.data(container.expression)) {
        .boolean_literal => |literal| literal.value,
        else => false,
    };
}
