const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/no-string-refs";

pub const Options = struct {
    no_template_literals: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    attribute: ast.JSXAttribute,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    const name = jsxIdentifierName(tree, attribute.name) orelse return;
    if (!std.mem.eql(u8, name, "ref")) return;
    if (!containsStringLiteral(tree, attribute.value, options)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Using string literals in ref attributes is deprecated.",
        tree.span(index),
    );
}

fn containsStringLiteral(tree: *const ast.Tree, value_index: ast.NodeIndex, options: Options) bool {
    if (value_index == .null) return false;

    return switch (tree.data(value_index)) {
        .string_literal => true,
        .jsx_expression_container => |container| switch (tree.data(container.expression)) {
            .string_literal => true,
            .template_literal => options.no_template_literals,
            else => false,
        },
        else => false,
    };
}

fn jsxIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}
