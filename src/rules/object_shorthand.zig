const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "object-shorthand";

pub const Options = struct {
    style: core.ObjectShorthandStyle = .always,
    avoid_quotes: bool = false,
    ignore_constructors: bool = false,
    avoid_explicit_return_arrows: bool = false,
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

    const shorthand_kind = shorthandKind(tree, property, options) orelse return;
    if (options.ignore_constructors and shorthand_kind == .method and isConstructorKey(tree, property.key)) return;
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

fn shorthandKind(tree: *const ast.Tree, property: ast.ObjectProperty, options: Options) ?ShorthandKind {
    if (!property.computed) {
        const key_name = propertyKeyName(tree, property.key);
        if (key_name != null and identifierReferenceNamed(tree, property.value, key_name.?)) return .property;
    }

    if (isAnonymousFunctionExpression(tree, property.value)) return .method;
    if (options.avoid_explicit_return_arrows and isExplicitReturnArrowFunction(tree, property.value)) return .method;
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

fn isConstructorKey(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const name = propertyKeyName(tree, index) orelse return false;
    for (name) |char| {
        if (char == '_' or char == '$' or (char >= '0' and char <= '9')) continue;
        return std.ascii.toUpper(char) == char;
    }
    return false;
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

fn isExplicitReturnArrowFunction(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const arrow = switch (tree.data(unwrapTransparent(tree, index))) {
        .arrow_function_expression => |arrow| arrow,
        else => return false,
    };
    if (arrow.expression) return false;
    if (containsLexicalReference(tree, arrow.body)) return false;

    const body = switch (tree.data(arrow.body)) {
        .function_body => |body| tree.extra(body.body),
        .block_statement => |block| tree.extra(block.body),
        else => return false,
    };
    if (body.len != 1) return false;
    return switch (tree.data(body[0])) {
        .return_statement => |statement| statement.argument != .null,
        else => false,
    };
}

fn containsLexicalReference(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    switch (tree.data(index)) {
        .this_expression, .super => return true,
        .identifier_reference => |identifier| return std.mem.eql(u8, tree.string(identifier.name), "arguments"),
        .meta_property => |property| return propertyNameEquals(tree, property.meta, "new") and propertyNameEquals(tree, property.property, "target"),
        .function, .class => return false,
        inline else => |node| return childrenContainLexicalReference(tree, @TypeOf(node), node),
    }
}

fn childrenContainLexicalReference(tree: *const ast.Tree, comptime T: type, node: T) bool {
    if (@typeInfo(T) != .@"struct") return false;

    inline for (@typeInfo(T).@"struct".fields) |field| {
        if (field.type == ast.NodeIndex) {
            if (containsLexicalReference(tree, @field(node, field.name))) return true;
        } else if (field.type == ast.IndexRange) {
            for (tree.extra(@field(node, field.name))) |child| {
                if (containsLexicalReference(tree, child)) return true;
            }
        }
    }
    return false;
}

fn propertyNameEquals(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    return switch (tree.data(index)) {
        .identifier_name => |identifier| std.mem.eql(u8, tree.string(identifier.name), expected),
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
