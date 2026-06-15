const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/ant/prefer-safe-image-renderer";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    opening: ast.JSXOpeningElement,
) Allocator.Error!void {
    const tag_name = jsxIdentifierName(tree, opening.name) orelse return;
    if (!isLowercaseNativeTagName(tag_name)) return;

    if (std.mem.eql(u8, tag_name, "img")) {
        const src_attribute = attributeNamed(tree, opening, "src") orelse return;
        if (src_attribute.value == .null) return;
        const src_node = jsxExpression(tree, src_attribute.value) orelse src_attribute.value;
        try checkImageSource(allocator, diagnostics, tree, src_node);
        return;
    }

    const style_attribute = attributeNamed(tree, opening, "style") orelse return;
    const style_expression = jsxExpression(tree, style_attribute.value) orelse return;
    const style_object = objectExpression(tree, style_expression) orelse return;

    for (tree.extra(style_object.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        const key = identifierName(tree, property.key) orelse continue;
        if (!std.mem.eql(u8, key, "backgroundImage") and !std.mem.eql(u8, key, "background")) continue;
        try reportVariableImageSource(allocator, diagnostics, tree, property.value);
    }
}

fn checkImageSource(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    src_node: ast.NodeIndex,
) Allocator.Error!void {
    if (stringLiteralValue(tree, src_node)) |value| {
        if (!containsAvifWithNonWordPrefix(value)) return;
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .@"error",
            id,
            tree.span(src_node),
            "图片链接为avif格式, 请使用safe-image-kit中的`Image|BackgroundImageDiv`组件渲染(否则不支持该格式的设备将无法降级): {s}",
            .{value},
        );
        return;
    }

    if (isNonStringLiteral(tree, src_node)) return;
    try reportVariableImageSource(allocator, diagnostics, tree, src_node);
}

fn reportVariableImageSource(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    src_node: ast.NodeIndex,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(src_node),
        "图片链接为变量(包括常量), 请使用safe-image-kit中的`Image|BackgroundImageDiv`组件渲染(避免出现意外空值造成额外非预期请求, 或avif格式图片无法加载等情况): {s}",
        .{nodeSource(tree, src_node)},
    );
}

fn isLowercaseNativeTagName(name: []const u8) bool {
    return name.len > 0 and std.ascii.isLower(name[0]);
}

fn attributeNamed(tree: *const ast.Tree, opening: ast.JSXOpeningElement, expected: []const u8) ?ast.JSXAttribute {
    for (tree.extra(opening.attributes)) |attribute_index| {
        const attribute = switch (tree.data(attribute_index)) {
            .jsx_attribute => |attribute| attribute,
            else => continue,
        };
        const name = jsxIdentifierName(tree, attribute.name) orelse continue;
        if (std.mem.eql(u8, name, expected)) return attribute;
    }
    return null;
}

fn jsxExpression(tree: *const ast.Tree, value_index: ast.NodeIndex) ?ast.NodeIndex {
    if (value_index == .null) return null;
    return switch (tree.data(value_index)) {
        .jsx_expression_container => |container| container.expression,
        else => null,
    };
}

fn objectExpression(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.ObjectExpression {
    return switch (tree.data(index)) {
        .object_expression => |object| object,
        else => null,
    };
}

fn jsxIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn identifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn stringLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn isNonStringLiteral(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .numeric_literal,
        .bigint_literal,
        .boolean_literal,
        .null_literal,
        .regexp_literal,
        => true,
        else => false,
    };
}

fn containsAvifWithNonWordPrefix(value: []const u8) bool {
    var start: usize = 0;
    while (std.mem.indexOfPos(u8, value, start, "avif")) |index| {
        if (index > 0 and !isRegexWord(value[index - 1])) return true;
        start = index + "avif".len;
    }
    return false;
}

fn isRegexWord(char: u8) bool {
    return std.ascii.isAlphanumeric(char) or char == '_';
}

fn nodeSource(tree: *const ast.Tree, index: ast.NodeIndex) []const u8 {
    const span = tree.span(index);
    if (span.start >= span.end or span.end > tree.source.len) return "";
    return tree.source[span.start..span.end];
}
