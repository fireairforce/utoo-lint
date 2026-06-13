const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const jsx_a11y_aria_props = @import("jsx_a11y_aria_props.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "jsx-a11y/aria-unsupported-elements";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    opening: ast.JSXOpeningElement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const tag_name = elementName(tree, opening.name) orelse return;
    if (!isReservedDomElement(tag_name)) return;

    for (tree.extra(opening.attributes)) |attribute_index| {
        const attribute = switch (tree.data(attribute_index)) {
            .jsx_attribute => |attribute| attribute,
            else => continue,
        };
        const name = attributeName(tree, attribute.name) orelse continue;
        var lower_buffer: [64]u8 = undefined;
        const lower_name = lowerAttributeName(name, &lower_buffer) orelse continue;
        if (!isUnsupportedAttribute(lower_name)) continue;

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "This element does not support ARIA roles, states and properties. Try removing the prop '{s}'.",
            .{lower_name},
        );
    }
}

fn isUnsupportedAttribute(name: []const u8) bool {
    if (std.ascii.eqlIgnoreCase(name, "role")) return true;
    return jsx_a11y_aria_props.isValidAriaAttribute(name);
}

fn elementName(tree: *const ast.Tree, name_index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn attributeName(tree: *const ast.Tree, name_index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn lowerAttributeName(name: []const u8, buffer: *[64]u8) ?[]const u8 {
    if (name.len > buffer.len) return null;
    for (name, 0..) |char, index| {
        buffer[index] = std.ascii.toLower(char);
    }
    return buffer[0..name.len];
}

fn isReservedDomElement(name: []const u8) bool {
    for (reserved_dom_elements) |element| {
        if (std.mem.eql(u8, name, element)) return true;
    }
    return false;
}

const reserved_dom_elements = [_][]const u8{
    "base",
    "col",
    "colgroup",
    "head",
    "html",
    "link",
    "meta",
    "noembed",
    "noscript",
    "param",
    "picture",
    "script",
    "source",
    "style",
    "title",
    "track",
};
