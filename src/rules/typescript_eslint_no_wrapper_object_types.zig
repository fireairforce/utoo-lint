const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-wrapper-object-types";

const WrapperObjectType = struct {
    name: []const u8,
    replacement: []const u8,
};

pub fn checkTypeReference(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    reference: ast.TSTypeReference,
) Allocator.Error!void {
    const wrapper = wrapperObjectTypeReference(tree, reference) orelse return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(reference.type_name),
        "Prefer `{s}` instead of the wrapper object type `{s}`.",
        .{ wrapper.replacement, wrapper.name },
    );
}

pub fn isWrapperObjectTypeReference(tree: *const ast.Tree, reference: ast.TSTypeReference) bool {
    return wrapperObjectTypeReference(tree, reference) != null;
}

fn wrapperObjectTypeReference(tree: *const ast.Tree, reference: ast.TSTypeReference) ?WrapperObjectType {
    const name = typeName(tree, reference.type_name) orelse return null;
    return wrapperObjectType(name);
}

fn wrapperObjectType(name: []const u8) ?WrapperObjectType {
    if (std.mem.eql(u8, name, "String")) return .{ .name = "String", .replacement = "string" };
    if (std.mem.eql(u8, name, "Boolean")) return .{ .name = "Boolean", .replacement = "boolean" };
    if (std.mem.eql(u8, name, "Number")) return .{ .name = "Number", .replacement = "number" };
    if (std.mem.eql(u8, name, "BigInt")) return .{ .name = "BigInt", .replacement = "bigint" };
    if (std.mem.eql(u8, name, "Symbol")) return .{ .name = "Symbol", .replacement = "symbol" };
    if (std.mem.eql(u8, name, "Object")) return .{ .name = "Object", .replacement = "object" };
    return null;
}

fn typeName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}
