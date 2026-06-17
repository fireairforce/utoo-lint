const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/typedef";

pub fn checkPropertySignature(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    signature: ast.TSPropertySignature,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (signature.type_annotation != .null) return;

    if (propertyName(tree, signature.key)) |name| {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .@"error",
            id,
            tree.span(index),
            "Expected {s} to have a type annotation.",
            .{name},
        );
        return;
    }

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Expected a type annotation.",
        tree.span(index),
    );
}

pub fn checkPropertyDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.PropertyDefinition,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (property.type_annotation != .null) return;

    if (propertyName(tree, property.key)) |name| {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .@"error",
            id,
            tree.span(index),
            "Expected {s} to have a type annotation.",
            .{name},
        );
        return;
    }

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Expected a type annotation.",
        tree.span(index),
    );
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
        .private_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}
