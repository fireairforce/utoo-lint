const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-caller";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isArgumentsObject(tree, member.object)) return;

    const name = propertyName(tree, member) orelse return;
    if (!isForbiddenProperty(name)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Avoid using arguments.caller or arguments.callee.",
        tree.span(index),
    );
}

fn isArgumentsObject(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const unwrapped = unwrapTransparent(tree, index);

    return switch (tree.data(unwrapped)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), "arguments"),
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

fn propertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;

    return if (member.computed)
        switch (tree.data(member.property)) {
            .string_literal => |literal| tree.string(literal.value),
            else => null,
        }
    else switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isForbiddenProperty(name: []const u8) bool {
    return std.mem.eql(u8, name, "caller") or
        std.mem.eql(u8, name, "callee");
}
