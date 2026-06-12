const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "operator-assignment";

const Reference = union(enum) {
    this,
    identifier: []const u8,
    member: struct {
        object: *const Reference,
        property: []const u8,
    },
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (expression.operator != .assign) return;

    const binary = switch (tree.data(unwrapTransparent(tree, expression.right))) {
        .binary_expression => |binary| binary,
        else => return,
    };
    if (!hasAssignmentOperator(binary.operator)) return;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const left = (try referenceFromExpression(arena_allocator, tree, expression.left)) orelse return;
    const right_left = (try referenceFromExpression(arena_allocator, tree, binary.left)) orelse return;
    if (!referencesEqual(left, right_left)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Assignment can be replaced with operator assignment.",
        tree.span(index),
    );
}

fn hasAssignmentOperator(operator: ast.BinaryOperator) bool {
    return switch (operator) {
        .add,
        .subtract,
        .multiply,
        .divide,
        .modulo,
        .exponent,
        .bitwise_or,
        .bitwise_xor,
        .bitwise_and,
        .left_shift,
        .right_shift,
        .unsigned_right_shift,
        => true,
        else => false,
    };
}

fn referenceFromExpression(
    allocator: Allocator,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!?*const Reference {
    if (index == .null) return null;

    switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| return try newReference(allocator, .{ .identifier = tree.string(identifier.name) }),
        .this_expression => return newReference(allocator, .this),
        .member_expression => |member| {
            const object = (try referenceFromExpression(allocator, tree, member.object)) orelse return null;
            const property = propertyName(tree, member) orelse return null;
            return try newReference(allocator, .{ .member = .{
                .object = object,
                .property = property,
            } });
        },
        else => return null,
    }
}

fn newReference(allocator: Allocator, reference: Reference) Allocator.Error!*const Reference {
    const owned = try allocator.create(Reference);
    owned.* = reference;
    return owned;
}

fn referencesEqual(left: *const Reference, right: *const Reference) bool {
    switch (left.*) {
        .this => return right.* == .this,
        .identifier => |left_name| return switch (right.*) {
            .identifier => |right_name| std.mem.eql(u8, left_name, right_name),
            else => false,
        },
        .member => |left_member| return switch (right.*) {
            .member => |right_member| std.mem.eql(u8, left_member.property, right_member.property) and
                referencesEqual(left_member.object, right_member.object),
            else => false,
        },
    }
}

fn propertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;

    return if (member.computed)
        switch (tree.data(member.property)) {
            .identifier_reference => |identifier| tree.string(identifier.name),
            .string_literal => |literal| tree.string(literal.value),
            .numeric_literal => |literal| tree.string(literal.raw),
            else => null,
        }
    else switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .private_identifier => |identifier| tree.string(identifier.name),
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
