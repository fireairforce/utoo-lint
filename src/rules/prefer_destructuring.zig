const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "prefer-destructuring";

const DestructuringKind = enum {
    object,
    array,
};

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
        const kind = preferredDestructuringKind(tree, declarator) orelse continue;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            diagnosticMessage(kind),
            tree.span(declarator.id),
        );
    }
}

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
) Allocator.Error!void {
    if (expression.operator != .assign) return;

    const kind = preferredAssignmentDestructuringKind(tree, expression) orelse return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        diagnosticMessage(kind),
        tree.span(expression.left),
    );
}

fn preferredDestructuringKind(tree: *const ast.Tree, declarator: ast.VariableDeclarator) ?DestructuringKind {
    if (declarator.init == .null) return null;

    const local_name = bindingIdentifierName(tree, declarator.id) orelse return null;

    const member = switch (tree.data(unwrapTransparent(tree, declarator.init))) {
        .member_expression => |member| member,
        else => return null,
    };
    if (member.optional) return null;

    if (isArrayIndexProperty(tree, member)) return .array;

    const property_name = propertyName(tree, member) orelse return null;
    return if (std.mem.eql(u8, local_name, property_name)) .object else null;
}

fn preferredAssignmentDestructuringKind(tree: *const ast.Tree, expression: ast.AssignmentExpression) ?DestructuringKind {
    const target_name = identifierReferenceName(tree, expression.left) orelse return null;

    const member = switch (tree.data(unwrapTransparent(tree, expression.right))) {
        .member_expression => |member| member,
        else => return null,
    };
    if (member.optional) return null;

    if (isArrayIndexProperty(tree, member)) return .array;

    const property_name = propertyName(tree, member) orelse return null;
    return if (std.mem.eql(u8, target_name, property_name)) .object else null;
}

fn diagnosticMessage(kind: DestructuringKind) []const u8 {
    return switch (kind) {
        .object => "Use object destructuring.",
        .array => "Use array destructuring.",
    };
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
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

fn isArrayIndexProperty(tree: *const ast.Tree, member: ast.MemberExpression) bool {
    if (!member.computed or member.property == .null) return false;

    return switch (tree.data(unwrapTransparent(tree, member.property))) {
        .numeric_literal => |literal| isArrayIndexNumber(literal.value(tree)),
        .string_literal => |literal| isArrayIndexString(tree.string(literal.value)),
        else => false,
    };
}

fn isArrayIndexNumber(value: f64) bool {
    return value >= 0 and value == @floor(value);
}

fn isArrayIndexString(value: []const u8) bool {
    if (value.len == 0) return false;
    for (value) |char| {
        if (char < '0' or char > '9') return false;
    }
    return true;
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
