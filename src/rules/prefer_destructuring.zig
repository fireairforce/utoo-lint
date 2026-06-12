const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "prefer-destructuring";

pub fn checkVariableDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
) Allocator.Error!void {
    for (tree.extra(declaration.declarators)) |declarator_index| {
        const declarator = switch (tree.data(declarator_index)) {
            .variable_declarator => |declarator| declarator,
            else => continue,
        };
        if (!shouldPreferObjectDestructuring(tree, declarator)) continue;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Use object destructuring.",
            tree.span(declarator.id),
        );
    }
}

fn shouldPreferObjectDestructuring(tree: *const ast.Tree, declarator: ast.VariableDeclarator) bool {
    if (declarator.init == .null) return false;

    const local_name = bindingIdentifierName(tree, declarator.id) orelse return false;

    const member = switch (tree.data(unwrapTransparent(tree, declarator.init))) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.optional) return false;

    const property_name = propertyName(tree, member) orelse return false;
    return std.mem.eql(u8, local_name, property_name);
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
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
