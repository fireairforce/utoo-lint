const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-self-assign";

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
    if (!isSelfAssignOperator(expression.operator)) return;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    if (try referenceFromExpression(arena_allocator, tree, expression.left)) |left| {
        if (try referenceFromExpression(arena_allocator, tree, expression.right)) |right| {
            if (referencesEqual(left, right)) {
                try addDiagnostic(allocator, diagnostics, tree, index);
                return;
            }
        }
    }

    if (expression.operator == .assign) {
        try checkPatternSelfAssign(allocator, diagnostics, tree, arena_allocator, expression.left, expression.right);
    }
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Self-assignment has no effect.",
        tree.span(index),
    );
}

fn isSelfAssignOperator(operator: ast.AssignmentOperator) bool {
    return switch (operator) {
        .assign,
        .logical_or_assign,
        .logical_and_assign,
        .nullish_assign,
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

    switch (tree.data(index)) {
        .identifier_reference => |identifier| return try newReference(allocator, .{ .identifier = tree.string(identifier.name) }),
        .this_expression => return newReference(allocator, .this),
        .chain_expression => |chain| return try referenceFromExpression(allocator, tree, chain.expression),
        .parenthesized_expression => |parenthesized| return try referenceFromExpression(allocator, tree, parenthesized.expression),
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

fn checkPatternSelfAssign(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    arena_allocator: Allocator,
    left_index: ast.NodeIndex,
    right_index: ast.NodeIndex,
) Allocator.Error!void {
    if (left_index == .null or right_index == .null) return;

    switch (tree.data(unwrapTransparent(tree, left_index))) {
        .array_pattern => |left| {
            const right = switch (tree.data(unwrapTransparent(tree, right_index))) {
                .array_expression => |right| right,
                else => return,
            };
            try checkArrayPatternSelfAssign(allocator, diagnostics, tree, arena_allocator, left, right);
        },
        .object_pattern => |left| {
            const right = switch (tree.data(unwrapTransparent(tree, right_index))) {
                .object_expression => |right| right,
                else => return,
            };
            try checkObjectPatternSelfAssign(allocator, diagnostics, tree, arena_allocator, left, right);
        },
        .assignment_pattern => {},
        else => {
            const left = (try referenceFromExpression(arena_allocator, tree, left_index)) orelse return;
            const right = (try referenceFromExpression(arena_allocator, tree, right_index)) orelse return;
            if (!referencesEqual(left, right)) return;
            try addDiagnostic(allocator, diagnostics, tree, right_index);
        },
    }
}

fn checkArrayPatternSelfAssign(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    arena_allocator: Allocator,
    left: ast.ArrayPattern,
    right: ast.ArrayExpression,
) Allocator.Error!void {
    const left_elements = tree.extra(left.elements);
    const right_elements = tree.extra(right.elements);
    const len = @min(left_elements.len, right_elements.len);

    for (left_elements[0..len], right_elements[0..len]) |left_element, right_element| {
        try checkPatternSelfAssign(allocator, diagnostics, tree, arena_allocator, left_element, right_element);
    }
}

fn checkObjectPatternSelfAssign(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    arena_allocator: Allocator,
    left: ast.ObjectPattern,
    right: ast.ObjectExpression,
) Allocator.Error!void {
    for (tree.extra(left.properties)) |left_property_index| {
        const left_property = switch (tree.data(left_property_index)) {
            .binding_property => |property| property,
            else => continue,
        };
        const key = patternPropertyName(tree, left_property.key, left_property.computed) orelse continue;
        const right_value = objectPropertyValueByName(tree, right, key) orelse continue;
        try checkPatternSelfAssign(allocator, diagnostics, tree, arena_allocator, left_property.value, right_value);
    }
}

fn objectPropertyValueByName(tree: *const ast.Tree, object: ast.ObjectExpression, name: []const u8) ?ast.NodeIndex {
    for (tree.extra(object.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        const key = patternPropertyName(tree, property.key, property.computed) orelse continue;
        if (std.mem.eql(u8, key, name)) return property.value;
    }

    return null;
}

fn patternPropertyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (index == .null) return null;

    return if (computed)
        switch (tree.data(index)) {
            .string_literal => |literal| tree.string(literal.value),
            .numeric_literal => |literal| tree.string(literal.raw),
            .template_literal => |literal| templateStringValue(tree, literal),
            else => null,
        }
    else switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
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
            .template_literal => |literal| templateStringValue(tree, literal),
            else => null,
        }
    else switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .private_identifier => |identifier| tree.string(identifier.name),
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
