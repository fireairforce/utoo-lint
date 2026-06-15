const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-prototype-builtins";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const name = builtinName(tree, call.callee) orelse return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Do not access Object.prototype method `{s}` from target object.",
        .{name},
    );
}

fn builtinName(tree: *const ast.Tree, callee: ast.NodeIndex) ?[]const u8 {
    const member = switch (tree.data(unwrapTransparent(tree, callee))) {
        .member_expression => |member| member,
        else => return null,
    };

    const name = propertyName(tree, member) orelse return null;
    if (!isPrototypeBuiltin(name)) return null;
    if (isSafePrototypeCall(tree, member.object)) return null;
    return name;
}

fn isSafePrototypeCall(tree: *const ast.Tree, object: ast.NodeIndex) bool {
    const member = switch (tree.data(unwrapTransparent(tree, object))) {
        .member_expression => |member| member,
        else => return false,
    };
    const property = propertyName(tree, member) orelse return false;
    if (!std.mem.eql(u8, property, "prototype")) return false;

    return isIdentifierReferenceNamed(tree, member.object, "Object");
}

fn propertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.computed) {
        return switch (tree.data(member.property)) {
            .string_literal => |literal| tree.string(literal.value),
            .template_literal => |literal| templateStringValue(tree, literal),
            else => null,
        };
    }

    return switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
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

fn isPrototypeBuiltin(name: []const u8) bool {
    return std.mem.eql(u8, name, "hasOwnProperty") or
        std.mem.eql(u8, name, "isPrototypeOf") or
        std.mem.eql(u8, name, "propertyIsEnumerable");
}

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
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
