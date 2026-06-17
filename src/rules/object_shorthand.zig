const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "object-shorthand";

pub const Options = struct {
    style: core.ObjectShorthandStyle = .always,
    avoid_quotes: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.ObjectProperty,
    index: ast.NodeIndex,
) Allocator.Error!void {
    return checkWithOptions(allocator, diagnostics, tree, property, index, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.ObjectProperty,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (property.kind != .init) return;

    if (options.style == .never) {
        const shorthand_kind: ?ShorthandKind = if (property.shorthand)
            .property
        else if (property.method)
            .method
        else
            null;
        if (shorthand_kind == null) return;
        return addDiagnostic(allocator, diagnostics, tree, index, shorthand_kind.?, options.style);
    }

    if (property.shorthand or property.method) return;
    if (options.avoid_quotes and isStringLiteralKey(tree, property.key)) return;

    const shorthand_kind = shorthandKind(tree, property) orelse return;
    if (!styleAllowsKind(options.style, shorthand_kind)) return;

    try addDiagnostic(allocator, diagnostics, tree, index, shorthand_kind, options.style);
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    shorthand_kind: ShorthandKind,
    style: core.ObjectShorthandStyle,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        if (style == .never) switch (shorthand_kind) {
            .property => "Expected property longform.",
            .method => "Expected method longform.",
        } else switch (shorthand_kind) {
            .property => "Expected property shorthand.",
            .method => "Expected method shorthand.",
        },
        tree.span(index),
    );
}

const ShorthandKind = enum {
    property,
    method,
};

fn shorthandKind(tree: *const ast.Tree, property: ast.ObjectProperty) ?ShorthandKind {
    if (!property.computed) {
        const key_name = propertyKeyName(tree, property.key);
        if (key_name != null and identifierReferenceNamed(tree, property.value, key_name.?)) return .property;
    }

    if (isAnonymousFunctionExpression(tree, property.value)) return .method;
    return null;
}

fn styleAllowsKind(style: core.ObjectShorthandStyle, shorthand_kind: ShorthandKind) bool {
    return switch (style) {
        .always => true,
        .methods => shorthand_kind == .method,
        .properties => shorthand_kind == .property,
        .never => false,
    };
}

fn isStringLiteralKey(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .string_literal => true,
        else => false,
    };
}

fn propertyKeyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn identifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
    };
}

fn isAnonymousFunctionExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .function => |function| function.type == .function_expression and function.id == .null,
        else => false,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;

    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |chain| current = chain.expression,
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            else => return current,
        }
    }

    return current;
}
