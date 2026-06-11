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

        try addDiagnostic(allocator, diagnostics, tree, property.key);
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

        try addDiagnostic(allocator, diagnostics, tree, property.key);
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

    try addDiagnostic(allocator, diagnostics, tree, index);
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
    if (isStaticPrototypeMember(tree, property.static, property.key)) return;

    try addDiagnostic(allocator, diagnostics, tree, index);
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unnecessarily computed property key.",
        tree.span(index),
    );
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
    return keyName(tree, method.key) != null and std.mem.eql(u8, keyName(tree, method.key).?, "constructor");
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
