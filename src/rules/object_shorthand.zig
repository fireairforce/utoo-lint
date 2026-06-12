const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "object-shorthand";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.ObjectProperty,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (property.computed or property.shorthand or property.kind != .init) return;

    if (!canUseShorthand(tree, property)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Expected property shorthand.",
        tree.span(index),
    );
}

fn canUseShorthand(tree: *const ast.Tree, property: ast.ObjectProperty) bool {
    const key_name = switch (tree.data(property.key)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => return false,
    };

    if (identifierReferenceNamed(tree, property.value, key_name)) return true;
    return isAnonymousFunctionExpression(tree, property.value);
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
