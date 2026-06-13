const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/prefer-es6-class";

pub fn checkObjectExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    parent: ?ast.NodeIndex,
) Allocator.Error!void {
    const parent_index = parent orelse return;
    const call = switch (tree.data(parent_index)) {
        .call_expression => |call| call,
        else => return,
    };

    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0 or arguments[0] != index) return;
    if (!isCreateReactClassCallee(tree, call.callee)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Component should use es6 class instead of createClass",
        tree.span(index),
    );
}

fn isCreateReactClassCallee(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const callee = unwrapTransparent(tree, index);

    if (identifierReferenceName(tree, callee)) |name| {
        return std.mem.eql(u8, name, "createReactClass");
    }

    const member = switch (tree.data(callee)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;

    const object = identifierReferenceName(tree, member.object) orelse return false;
    if (!std.mem.eql(u8, object, "React")) return false;

    const property = propertyName(tree, member.property) orelse return false;
    return std.mem.eql(u8, property, "createReactClass");
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
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
