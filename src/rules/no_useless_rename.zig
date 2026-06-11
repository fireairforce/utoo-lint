const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-useless-rename";

pub fn checkImportSpecifier(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    specifier: ast.ImportSpecifier,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!hasAsBetween(tree, specifier.imported, specifier.local)) return;

    const imported = propertyName(tree, specifier.imported) orelse return;
    const local = bindingName(tree, specifier.local) orelse return;
    if (!std.mem.eql(u8, imported, local)) return;

    try addDiagnostic(allocator, diagnostics, tree, index);
}

pub fn checkExportSpecifier(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    specifier: ast.ExportSpecifier,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!hasAsBetween(tree, specifier.local, specifier.exported)) return;

    const local = referenceOrPropertyName(tree, specifier.local) orelse return;
    const exported = propertyName(tree, specifier.exported) orelse return;
    if (!std.mem.eql(u8, local, exported)) return;

    try addDiagnostic(allocator, diagnostics, tree, index);
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
        if (property.shorthand or property.computed) continue;

        const key = propertyName(tree, property.key) orelse continue;
        const value = bindingOrAssignmentName(tree, property.value) orelse continue;
        if (!std.mem.eql(u8, key, value)) continue;

        try addDiagnostic(allocator, diagnostics, tree, property_index);
    }
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
        "Useless rename to the same name.",
        tree.span(index),
    );
}

fn bindingOrAssignmentName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .assignment_pattern => |pattern| bindingName(tree, pattern.left),
        else => bindingName(tree, index),
    };
}

fn bindingName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn referenceOrPropertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => propertyName(tree, index),
    };
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
        else => null,
    };
}

fn hasAsBetween(tree: *const ast.Tree, left: ast.NodeIndex, right: ast.NodeIndex) bool {
    if (left == .null or right == .null) return false;

    const left_span = tree.span(left);
    const right_span = tree.span(right);
    const left_end: usize = @intCast(left_span.end);
    const right_start: usize = @intCast(right_span.start);
    if (left_end > right_start or right_start > tree.source.len) return false;

    var iter = std.mem.tokenizeAny(u8, tree.source[left_end..right_start], " \t\r\n");
    while (iter.next()) |token| {
        if (std.mem.eql(u8, token, "as")) return true;
    }
    return false;
}
