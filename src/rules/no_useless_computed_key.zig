const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-useless-computed-key";

pub fn checkObjectExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ObjectExpression,
) Allocator.Error!void {
    for (tree.extra(expression.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        if (!property.computed) continue;
        if (!isStaticKey(tree, property.key)) continue;
        if (isObjectProtoProperty(tree, property)) continue;

        try addDiagnostic(allocator, diagnostics, tree, property.key, property.key);
    }
}

pub fn checkObjectPattern(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    pattern: ast.ObjectPattern,
) Allocator.Error!void {
    for (tree.extra(pattern.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .binding_property => |property| property,
            else => continue,
        };
        if (!property.computed) continue;
        if (!isStaticKey(tree, property.key)) continue;

        try addDiagnostic(allocator, diagnostics, tree, property.key, property.key);
    }
}

pub fn checkMethodDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    method: ast.MethodDefinition,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!method.computed) return;
    if (!isStaticKey(tree, method.key)) return;
    if (isClassConstructorMethod(tree, method)) return;
    if (isStaticPrototypeMember(tree, method.static, method.key)) return;

    try addDiagnostic(allocator, diagnostics, tree, index, method.key);
}

pub fn checkPropertyDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.PropertyDefinition,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!property.computed) return;
    if (!isStaticKey(tree, property.key)) return;
    if (isConstructorKey(tree, property.key)) return;
    if (isStaticPrototypeMember(tree, property.static, property.key)) return;

    try addDiagnostic(allocator, diagnostics, tree, index, property.key);
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    diagnostic_index: ast.NodeIndex,
    key_index: ast.NodeIndex,
) Allocator.Error!void {
    const key_span = tree.span(key_index);
    const fix_span = computedKeyFixSpan(tree, key_span) orelse {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Unnecessarily computed property key.",
            tree.span(diagnostic_index),
        );
        return;
    };

    const key_source = tree.source[key_span.start..key_span.end];
    var owned_replacement: ?[]u8 = null;
    defer if (owned_replacement) |replacement| allocator.free(replacement);
    const replacement = if (needsSpaceBeforeKey(tree, key_index, fix_span)) replacement: {
        const value = try std.fmt.allocPrint(allocator, " {s}", .{key_source});
        owned_replacement = value;
        break :replacement value;
    } else key_source;

    try core.addDiagnosticWithFix(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unnecessarily computed property key.",
        tree.span(diagnostic_index),
        .{
            .span = fix_span,
            .replacement = replacement,
        },
    );
}

fn computedKeyFixSpan(tree: *const ast.Tree, key_span: ast.Span) ?ast.Span {
    const source = tree.source;
    var start: usize = @intCast(key_span.start);
    while (start > 0 and std.ascii.isWhitespace(source[start - 1])) start -= 1;
    if (start == 0 or source[start - 1] != '[') return null;
    const left_bracket = start - 1;

    var end: usize = @intCast(key_span.end);
    while (end < source.len and std.ascii.isWhitespace(source[end])) end += 1;
    if (end >= source.len or source[end] != ']') return null;

    return .{ .start = @intCast(left_bracket), .end = @intCast(end + 1) };
}

fn needsSpaceBeforeKey(tree: *const ast.Tree, key_index: ast.NodeIndex, fix_span: ast.Span) bool {
    if (tree.data(key_index) != .numeric_literal) return false;

    const key_span = tree.span(key_index);
    const key_source = tree.source[key_span.start..key_span.end];
    if (key_source.len == 0 or key_source[0] == '.') return false;

    const start: usize = @intCast(fix_span.start);
    if (start == 0) return false;
    return isIdentifierPart(tree.source[start - 1]);
}

fn isIdentifierPart(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '$' or byte >= 0x80;
}

fn isStaticKey(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .string_literal,
        .numeric_literal,
        => true,
        else => false,
    };
}

fn isObjectProtoProperty(tree: *const ast.Tree, property: ast.ObjectProperty) bool {
    if (!property.computed or property.kind != .init or property.method) return false;
    return keyName(tree, property.key) != null and std.mem.eql(u8, keyName(tree, property.key).?, "__proto__");
}

fn isClassConstructorMethod(tree: *const ast.Tree, method: ast.MethodDefinition) bool {
    if (method.static or method.kind != .method) return false;
    return isConstructorKey(tree, method.key);
}

fn isConstructorKey(tree: *const ast.Tree, key: ast.NodeIndex) bool {
    return keyName(tree, key) != null and std.mem.eql(u8, keyName(tree, key).?, "constructor");
}

fn isStaticPrototypeMember(tree: *const ast.Tree, is_static: bool, key: ast.NodeIndex) bool {
    if (!is_static) return false;
    return keyName(tree, key) != null and std.mem.eql(u8, keyName(tree, key).?, "prototype");
}

fn keyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
        else => null,
    };
}
