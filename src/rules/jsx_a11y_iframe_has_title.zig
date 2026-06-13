const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "jsx-a11y/iframe-has-title";

const message = "<iframe> elements must have a unique title property.";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    opening: ast.JSXOpeningElement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isIframeElement(tree, opening.name)) return;
    if (hasValidTitle(tree, opening)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        message,
        tree.span(index),
    );
}

fn isIframeElement(tree: *const ast.Tree, name_index: ast.NodeIndex) bool {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| std.mem.eql(u8, tree.string(identifier.name), "iframe"),
        else => false,
    };
}

fn hasValidTitle(tree: *const ast.Tree, opening: ast.JSXOpeningElement) bool {
    for (tree.extra(opening.attributes)) |attribute_index| {
        const attribute = switch (tree.data(attribute_index)) {
            .jsx_attribute => |attribute| attribute,
            else => continue,
        };
        const name = attributeName(tree, attribute.name) orelse continue;
        if (!std.mem.eql(u8, name, "title")) continue;
        return titleValueIsValid(tree, attribute.value);
    }
    return false;
}

fn attributeName(tree: *const ast.Tree, name_index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn titleValueIsValid(tree: *const ast.Tree, value_index: ast.NodeIndex) bool {
    if (value_index == .null) return false;

    return switch (tree.data(value_index)) {
        .string_literal => |literal| tree.string(literal.value).len > 0,
        .jsx_expression_container => |container| expressionValueIsValid(tree, container.expression),
        else => true,
    };
}

fn expressionValueIsValid(tree: *const ast.Tree, expression_index: ast.NodeIndex) bool {
    return switch (tree.data(expression_index)) {
        .string_literal => |literal| tree.string(literal.value).len > 0,
        .boolean_literal,
        .null_literal,
        .numeric_literal,
        => false,
        .identifier_reference => |identifier| !std.mem.eql(u8, tree.string(identifier.name), "undefined"),
        else => true,
    };
}
