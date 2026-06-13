const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "jsx-a11y/no-access-key";

const message = "No access key attribute allowed. Inconsistencies between keyboard shortcuts and keyboard commands used by screen readers and keyboard-only users create a11y complications.";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    opening: ast.JSXOpeningElement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    for (tree.extra(opening.attributes)) |attribute_index| {
        const attribute = switch (tree.data(attribute_index)) {
            .jsx_attribute => |attribute| attribute,
            else => continue,
        };
        const name = attributeName(tree, attribute.name) orelse continue;
        if (!std.ascii.eqlIgnoreCase(name, "accesskey")) continue;
        if (!attributeValueIsTruthy(tree, attribute.value)) continue;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            message,
            tree.span(index),
        );
        return;
    }
}

fn attributeName(tree: *const ast.Tree, name_index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn attributeValueIsTruthy(tree: *const ast.Tree, value_index: ast.NodeIndex) bool {
    if (value_index == .null) return true;
    return switch (tree.data(value_index)) {
        .string_literal => |literal| tree.string(literal.value).len > 0,
        .jsx_expression_container => |container| expressionValueIsTruthy(tree, container.expression),
        else => true,
    };
}

fn expressionValueIsTruthy(tree: *const ast.Tree, expression_index: ast.NodeIndex) bool {
    return switch (tree.data(expression_index)) {
        .boolean_literal => |literal| literal.value,
        .null_literal => false,
        .numeric_literal => |literal| !numericLiteralIsZero(tree.string(literal.raw)),
        .identifier_reference => |identifier| !std.mem.eql(u8, tree.string(identifier.name), "undefined"),
        else => true,
    };
}

fn numericLiteralIsZero(raw: []const u8) bool {
    for (raw) |byte| {
        if (byte == '0' or byte == '_' or byte == '.') continue;
        return false;
    }
    return true;
}
