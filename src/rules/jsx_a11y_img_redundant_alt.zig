const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "jsx-a11y/img-redundant-alt";

const message = "Redundant alt attribute. Screen-readers already announce `img` tags as an image. You don’t need to use the words `image`, `photo,` or `picture` (or any specified custom words) in the alt prop.";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    opening: ast.JSXOpeningElement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isImgElement(tree, opening.name)) return;
    if (isAriaHidden(tree, opening)) return;

    const alt = attributeNamed(tree, opening, "alt") orelse return;
    const value = stringValue(tree, alt.value) orelse return;
    if (!containsRedundantWord(value)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        message,
        tree.span(index),
    );
}

fn isImgElement(tree: *const ast.Tree, name_index: ast.NodeIndex) bool {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| std.mem.eql(u8, tree.string(identifier.name), "img"),
        else => false,
    };
}

fn attributeNamed(tree: *const ast.Tree, opening: ast.JSXOpeningElement, name: []const u8) ?ast.JSXAttribute {
    for (tree.extra(opening.attributes)) |attribute_index| {
        const attribute = switch (tree.data(attribute_index)) {
            .jsx_attribute => |attribute| attribute,
            else => continue,
        };
        const attribute_name = attributeName(tree, attribute.name) orelse continue;
        if (std.mem.eql(u8, attribute_name, name)) return attribute;
    }
    return null;
}

fn attributeName(tree: *const ast.Tree, name_index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isAriaHidden(tree: *const ast.Tree, opening: ast.JSXOpeningElement) bool {
    const attribute = attributeNamed(tree, opening, "aria-hidden") orelse return false;
    if (attribute.value == .null) return true;
    return switch (tree.data(attribute.value)) {
        .string_literal => |literal| std.ascii.eqlIgnoreCase(tree.string(literal.value), "true"),
        .jsx_expression_container => |container| switch (tree.data(container.expression)) {
            .boolean_literal => |literal| literal.value,
            else => false,
        },
        else => false,
    };
}

fn stringValue(tree: *const ast.Tree, value_index: ast.NodeIndex) ?[]const u8 {
    if (value_index == .null) return null;
    return switch (tree.data(value_index)) {
        .string_literal => |literal| tree.string(literal.value),
        .jsx_expression_container => |container| switch (tree.data(container.expression)) {
            .string_literal => |literal| tree.string(literal.value),
            .template_literal => |literal| firstTemplateQuasi(tree, literal),
            else => null,
        },
        else => null,
    };
}

fn firstTemplateQuasi(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;
    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return null;
    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
}

fn containsRedundantWord(value: []const u8) bool {
    var words = std.mem.tokenizeAny(u8, value, " \t\r\n");
    while (words.next()) |word| {
        if (equalsRedundantWord(word)) return true;
    }
    return false;
}

fn equalsRedundantWord(word: []const u8) bool {
    return std.ascii.eqlIgnoreCase(word, "image") or
        std.ascii.eqlIgnoreCase(word, "photo") or
        std.ascii.eqlIgnoreCase(word, "picture");
}
