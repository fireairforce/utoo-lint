const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/ant/jsx-handler-names";

const handler_prefix_message = "(on|handle)";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    attribute: ast.JSXAttribute,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const prop_key = jsxIdentifierName(tree, attribute.name) orelse return;
    if (std.mem.eql(u8, prop_key, "ref")) return;
    if (!isEventHandlerProp(prop_key)) return;

    const expression = jsxExpression(tree, attribute.value) orelse return;
    if (isInlineArrow(tree, expression)) return;

    const owned_prop_value = try normalizedExpressionSource(allocator, tree, expression);
    defer allocator.free(owned_prop_value);

    var prop_value: []const u8 = owned_prop_value;
    prop_value = stripThisPrefix(prop_value);
    prop_value = stripBindPrefix(prop_value);

    if (isNamedHandler(prop_value)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Handler function for {s} prop key must be a camelCase name beginning with '{s}' only",
        .{ prop_key, handler_prefix_message },
    );
}

fn jsxExpression(tree: *const ast.Tree, value_index: ast.NodeIndex) ?ast.NodeIndex {
    if (value_index == .null) return null;
    return switch (tree.data(value_index)) {
        .jsx_expression_container => |container| if (container.expression == .null) null else container.expression,
        else => null,
    };
}

fn isInlineArrow(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .arrow_function_expression => true,
        else => false,
    };
}

fn normalizedExpressionSource(
    allocator: Allocator,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error![]u8 {
    const span = tree.span(index);
    if (span.start >= span.end or span.end > tree.source.len) return allocator.dupe(u8, "");

    var normalized: std.ArrayList(u8) = .empty;
    errdefer normalized.deinit(allocator);
    for (tree.source[span.start..span.end]) |char| {
        if (std.ascii.isWhitespace(char)) continue;
        try normalized.append(allocator, char);
    }
    return normalized.toOwnedSlice(allocator);
}

fn stripThisPrefix(value: []const u8) []const u8 {
    const prefix = "this.";
    if (std.mem.startsWith(u8, value, prefix)) {
        return value[prefix.len..];
    }
    return value;
}

fn stripBindPrefix(value: []const u8) []const u8 {
    const bind = "::";
    if (std.mem.lastIndexOf(u8, value, bind)) |index| {
        return value[index + bind.len ..];
    }
    return value;
}

fn isEventHandlerProp(prop_key: []const u8) bool {
    return startsWithHandlerPrefix(prop_key) and hasUppercaseAfterPrefix(prop_key);
}

fn isNamedHandler(value: []const u8) bool {
    if (startsWithQualifiedHandler(value)) return true;
    return startsWithHandlerPrefix(value) and hasUppercaseAfterPrefix(value);
}

fn startsWithQualifiedHandler(value: []const u8) bool {
    if (std.mem.startsWith(u8, value, "props.")) {
        const tail = value["props.".len..];
        return startsWithHandlerPrefix(tail) and hasUppercaseAfterPrefix(tail);
    }

    const dot = std.mem.lastIndexOfScalar(u8, value, '.') orelse return false;
    const tail = value[dot + 1 ..];
    return startsWithHandlerPrefix(tail) and hasUppercaseAfterPrefix(tail);
}

fn startsWithHandlerPrefix(value: []const u8) bool {
    return std.mem.startsWith(u8, value, "on") or std.mem.startsWith(u8, value, "handle");
}

fn hasUppercaseAfterPrefix(value: []const u8) bool {
    if (std.mem.startsWith(u8, value, "handle")) {
        return hasUppercaseAt(value, "handle".len);
    }
    if (std.mem.startsWith(u8, value, "on")) {
        return hasUppercaseAt(value, "on".len);
    }
    return false;
}

fn hasUppercaseAt(value: []const u8, offset: usize) bool {
    var index = offset;
    while (index < value.len and std.ascii.isDigit(value[index])) : (index += 1) {}
    if (index >= value.len) return false;
    return std.ascii.isUpper(value[index]);
}

fn jsxIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}
