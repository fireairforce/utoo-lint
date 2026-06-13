const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/no-multi-comp";

pub const State = struct {
    component_count: usize = 0,
};

pub fn checkClass(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    class: ast.Class,
    index: ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    if (!isReactComponentClass(tree, class)) return;

    state.component_count += 1;
    if (state.component_count <= 1) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Declare only one React component per file",
        tree.span(index),
    );
}

fn isReactComponentClass(tree: *const ast.Tree, class: ast.Class) bool {
    if (class.super_class == .null) return false;
    const super_class = unwrapTransparent(tree, class.super_class);

    if (identifierReferenceName(tree, super_class)) |name| {
        return std.mem.eql(u8, name, "Component") or std.mem.eql(u8, name, "PureComponent");
    }

    const member = switch (tree.data(super_class)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;
    if (!isIdentifierReferenceNamed(tree, unwrapTransparent(tree, member.object), "React")) return false;
    const property = propertyName(tree, member.property, false) orelse return false;
    return std.mem.eql(u8, property, "Component") or std.mem.eql(u8, property, "PureComponent");
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (computed) return null;
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    const name = identifierReferenceName(tree, index) orelse return false;
    return std.mem.eql(u8, name, expected);
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
