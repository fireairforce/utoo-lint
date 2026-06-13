const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/explicit-member-accessibility";

pub fn checkMethodDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    method: ast.MethodDefinition,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (method.accessibility != .public) return;

    const member_name = methodName(tree, method);
    const description = switch (method.kind) {
        .get => "get property accessor",
        .set => "set property accessor",
        else => "method definition",
    };

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Public accessibility modifier on {s} {s}.",
        .{ description, member_name },
    );
}

pub fn checkPropertyDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.PropertyDefinition,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (property.accessibility != .public) return;

    const member_name = staticKeyName(tree, property.key, property.computed) orelse "member";
    const description = if (property.accessor) "accessor property" else "class property";

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Public accessibility modifier on {s} {s}.",
        .{ description, member_name },
    );
}

fn methodName(tree: *const ast.Tree, method: ast.MethodDefinition) []const u8 {
    if (method.kind == .constructor and !method.static) return "constructor";
    return staticKeyName(tree, method.key, method.computed) orelse "member";
}

fn staticKeyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_name => |identifier| if (computed) null else tree.string(identifier.name),
        .private_identifier => |identifier| if (computed) null else tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
        else => null,
    };
}
