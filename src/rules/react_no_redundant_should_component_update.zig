const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/no-redundant-should-component-update";

pub fn checkClass(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    class: ast.Class,
    index: ast.NodeIndex,
    parent: ?ast.NodeIndex,
) Allocator.Error!void {
    if (!isPureComponentClass(tree, class)) return;
    if (!hasShouldComponentUpdate(tree, class)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "{s} does not need shouldComponentUpdate when extending React.PureComponent.",
        .{className(tree, class, parent)},
    );
}

fn isPureComponentClass(tree: *const ast.Tree, class: ast.Class) bool {
    if (class.super_class == .null) return false;
    const super_class = unwrapTransparent(tree, class.super_class);

    if (identifierReferenceName(tree, super_class)) |name| {
        return std.mem.eql(u8, name, "PureComponent");
    }

    const member = switch (tree.data(super_class)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;
    if (!isIdentifierReferenceNamed(tree, unwrapTransparent(tree, member.object), "React")) return false;
    const property = propertyName(tree, member.property, false) orelse return false;
    return std.mem.eql(u8, property, "PureComponent");
}

fn hasShouldComponentUpdate(tree: *const ast.Tree, class: ast.Class) bool {
    const body = switch (tree.data(class.body)) {
        .class_body => |body| body,
        else => return false,
    };

    for (tree.extra(body.body)) |member_index| {
        switch (tree.data(member_index)) {
            .method_definition => |method| {
                const name = propertyName(tree, method.key, method.computed) orelse continue;
                if (std.mem.eql(u8, name, "shouldComponentUpdate")) return true;
            },
            .property_definition => |property| {
                const name = propertyName(tree, property.key, property.computed) orelse continue;
                if (std.mem.eql(u8, name, "shouldComponentUpdate")) return true;
            },
            else => {},
        }
    }

    return false;
}

fn className(tree: *const ast.Tree, class: ast.Class, parent: ?ast.NodeIndex) []const u8 {
    if (bindingIdentifierName(tree, class.id)) |name| return name;
    if (parent) |parent_index| {
        if (tree.data(parent_index) == .variable_declarator) {
            const declarator = tree.data(parent_index).variable_declarator;
            if (bindingIdentifierName(tree, declarator.id)) |name| return name;
        }
    }
    return "";
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (computed) return null;
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
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
