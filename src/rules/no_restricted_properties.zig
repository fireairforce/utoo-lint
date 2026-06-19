const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-restricted-properties";

pub fn checkMemberExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
    index: ast.NodeIndex,
    restrictions: core.NoRestrictedProperties,
) Allocator.Error!void {
    const object = objectName(tree, member.object) orelse return;
    const property = propertyNameFromMember(tree, member) orelse return;

    for (0..restrictions.count) |restriction_index| {
        const restriction = restrictions.at(restriction_index);
        if (!matchesMemberRestriction(restriction, object, property)) continue;
        try addDiagnostic(allocator, diagnostics, tree, index, restriction, object, property);
    }
}

pub fn checkObjectPattern(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    pattern: ast.ObjectPattern,
    restrictions: core.NoRestrictedProperties,
) Allocator.Error!void {
    for (tree.extra(pattern.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .binding_property => |property| property,
            else => continue,
        };
        const name = propertyName(tree, property.key, property.computed) orelse continue;

        for (0..restrictions.count) |restriction_index| {
            const restriction = restrictions.at(restriction_index);
            if (restriction.has_object) continue;
            if (!matchesPropertyRestriction(restriction, name)) continue;
            try addPropertyDiagnostic(allocator, diagnostics, tree, property_index, restriction, name);
        }
    }
}

fn matchesMemberRestriction(restriction: *const core.NoRestrictedPropertyEntry, object: []const u8, property: []const u8) bool {
    if (restriction.object()) |restricted_object| {
        if (!std.mem.eql(u8, restricted_object, object)) return false;
    }
    if (restriction.property()) |restricted_property| {
        if (!std.mem.eql(u8, restricted_property, property)) return false;
    }
    if (restriction.allow_objects.contains(object)) return false;
    if (restriction.allow_properties.contains(property)) return false;
    return true;
}

fn matchesPropertyRestriction(restriction: *const core.NoRestrictedPropertyEntry, property: []const u8) bool {
    const restricted_property = restriction.property() orelse return false;
    if (!std.mem.eql(u8, restricted_property, property)) return false;
    return true;
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    restriction: *const core.NoRestrictedPropertyEntry,
    object: []const u8,
    property: []const u8,
) Allocator.Error!void {
    if (restriction.message()) |message| {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "Disallowed object property: {s}.{s}. {s}",
            .{ object, property, message },
        );
    } else {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "Disallowed object property: {s}.{s}.",
            .{ object, property },
        );
    }
}

fn addPropertyDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    restriction: *const core.NoRestrictedPropertyEntry,
    property: []const u8,
) Allocator.Error!void {
    if (restriction.message()) |message| {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "Disallowed object property: {s}. {s}",
            .{ property, message },
        );
    } else {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "Disallowed object property: {s}.",
            .{property},
        );
    }
}

fn objectName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn propertyNameFromMember(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;
    return propertyName(tree, member.property, member.computed);
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (computed) {
        return switch (tree.data(index)) {
            .string_literal => |literal| tree.string(literal.value),
            .template_literal => |literal| templateStringValue(tree, literal),
            else => null,
        };
    }

    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
        else => null,
    };
}

fn templateStringValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;

    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return "";

    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
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
