const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "logical-assignment-operators";

pub const Style = enum {
    always,
    never,
};

pub const Options = struct {
    style: Style = .always,
};

const Reference = union(enum) {
    this,
    identifier: []const u8,
    member: struct {
        object: *const Reference,
        property: []const u8,
    },
};

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkAssignmentExpressionWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkAssignmentExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (options.style == .never) {
        try checkLogicalAssignmentOperator(allocator, diagnostics, tree, expression, index);
        return;
    }

    if (expression.operator != .assign) return;

    const logical = switch (tree.data(unwrapTransparent(tree, expression.right))) {
        .logical_expression => |logical| logical,
        else => return,
    };

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const left = (try referenceFromExpression(arena_allocator, tree, expression.left)) orelse return;
    const right_left = (try referenceFromExpression(arena_allocator, tree, logical.left)) orelse return;
    if (!referencesEqual(left, right_left)) return;

    try addDiagnostic(allocator, diagnostics, tree, index, logical.operator);
}

fn checkLogicalAssignmentOperator(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const operator = logicalOperatorFromAssignment(expression.operator) orelse return;
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Unexpected logical assignment operator `{s}=`.",
        .{operator.toString()},
    );
}

pub fn checkLogicalExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.LogicalExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const assignment = switch (tree.data(unwrapTransparent(tree, expression.right))) {
        .assignment_expression => |assignment| assignment,
        else => return,
    };
    if (assignment.operator != .assign) return;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const left = (try referenceFromExpression(arena_allocator, tree, expression.left)) orelse return;
    const assignment_left = (try referenceFromExpression(arena_allocator, tree, assignment.left)) orelse return;
    if (!referencesEqual(left, assignment_left)) return;

    try addDiagnostic(allocator, diagnostics, tree, index, expression.operator);
}

pub fn checkIfStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.IfStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (statement.alternate != .null) return;

    const assignment = assignmentFromStatement(tree, statement.consequent) orelse return;
    if (assignment.operator != .assign) return;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const test_reference = (try conditionReference(arena_allocator, tree, statement.@"test")) orelse return;
    const assignment_left = (try referenceFromExpression(arena_allocator, tree, assignment.left)) orelse return;
    if (!referencesEqual(test_reference.reference, assignment_left)) return;

    try addDiagnostic(allocator, diagnostics, tree, index, test_reference.operator);
}

const ConditionReference = struct {
    reference: *const Reference,
    operator: ast.LogicalOperator,
};

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    operator: ast.LogicalOperator,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Assignment can be replaced with `{s}=`.",
        .{operator.toString()},
    );
}

fn logicalOperatorFromAssignment(operator: ast.AssignmentOperator) ?ast.LogicalOperator {
    return switch (operator) {
        .logical_or_assign => .@"or",
        .logical_and_assign => .@"and",
        .nullish_assign => .nullish_coalescing,
        else => null,
    };
}

fn conditionReference(
    allocator: Allocator,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!?ConditionReference {
    const unwrapped = unwrapTransparent(tree, index);
    switch (tree.data(unwrapped)) {
        .unary_expression => |expression| {
            if (expression.operator != .logical_not) return null;
            const reference = (try referenceFromExpression(allocator, tree, expression.argument)) orelse return null;
            return .{
                .reference = reference,
                .operator = .@"or",
            };
        },
        .binary_expression => |expression| {
            if (expression.operator != .equal) return null;
            if (isNullLiteral(tree, expression.left)) {
                const reference = (try referenceFromExpression(allocator, tree, expression.right)) orelse return null;
                return .{
                    .reference = reference,
                    .operator = .nullish_coalescing,
                };
            }
            if (isNullLiteral(tree, expression.right)) {
                const reference = (try referenceFromExpression(allocator, tree, expression.left)) orelse return null;
                return .{
                    .reference = reference,
                    .operator = .nullish_coalescing,
                };
            }
            return null;
        },
        else => {
            const reference = (try referenceFromExpression(allocator, tree, unwrapped)) orelse return null;
            return .{
                .reference = reference,
                .operator = .@"and",
            };
        },
    }
}

fn assignmentFromStatement(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.AssignmentExpression {
    const unwrapped = unwrapTransparent(tree, index);
    switch (tree.data(unwrapped)) {
        .expression_statement => |statement| return assignmentFromExpression(tree, statement.expression),
        .block_statement => |block| {
            const statements = tree.extra(block.body);
            if (statements.len != 1) return null;
            return assignmentFromStatement(tree, statements[0]);
        },
        else => return null,
    }
}

fn assignmentFromExpression(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.AssignmentExpression {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .assignment_expression => |assignment| assignment,
        else => null,
    };
}

fn isNullLiteral(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .null_literal => true,
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
