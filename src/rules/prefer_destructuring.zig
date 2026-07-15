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

pub const Options = struct {
    variable_declarator_array: bool = true,
    variable_declarator_object: bool = true,
    assignment_expression_array: bool = true,
    assignment_expression_object: bool = true,
    enforce_for_renamed_properties: bool = false,
};

pub fn checkVariableDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
) Allocator.Error!void {
    return checkVariableDeclarationWithOptions(allocator, diagnostics, tree, declaration, .{});
}

pub fn checkVariableDeclarationWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    options: Options,
) Allocator.Error!void {
    for (tree.extra(declaration.declarators)) |declarator_index| {
        const declarator = switch (tree.data(declarator_index)) {
            .variable_declarator => |declarator| declarator,
            else => continue,
        };
        const kind = preferredDestructuringKind(tree, declarator, options) orelse continue;
        if (!allowsVariableDeclarator(options, kind)) continue;

        if (kind == .object) {
            if (try simpleObjectDestructuringReplacement(allocator, tree, declarator_index, declarator)) |replacement| {
                defer allocator.free(replacement);
                try core.addDiagnosticWithFix(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    diagnosticMessage(kind),
                    tree.span(declarator.id),
                    .{ .span = tree.span(declarator_index), .replacement = replacement },
                );
                continue;
            }
        }

        try addDiagnostic(allocator, diagnostics, tree, declarator.id, kind);
    }
}

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
) Allocator.Error!void {
    return checkAssignmentExpressionWithOptions(allocator, diagnostics, tree, expression, .{});
}

pub fn checkAssignmentExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    options: Options,
) Allocator.Error!void {
    if (expression.operator != .assign) return;

    const kind = preferredAssignmentDestructuringKind(tree, expression, options) orelse return;
    if (!allowsAssignmentExpression(options, kind)) return;

    try addDiagnostic(allocator, diagnostics, tree, expression.left, kind);
}

fn simpleObjectDestructuringReplacement(
    allocator: Allocator,
    tree: *const ast.Tree,
    declarator_index: ast.NodeIndex,
    declarator: ast.VariableDeclarator,
) Allocator.Error!?[]u8 {
    const local_name = bindingIdentifierName(tree, declarator.id) orelse return null;
    const member = switch (tree.data(declarator.init)) {
        .member_expression => |member| member,
        else => return null,
    };
    if (member.computed or member.optional or member.property == .null) return null;

    const property_name = switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => return null,
    };
    if (!std.mem.eql(u8, local_name, property_name)) return null;
    if (tree.data(unwrapTransparent(tree, member.object)) == .super) return null;

    const declarator_span = tree.span(declarator_index);
    const object_span = tree.span(member.object);
    if (hasCommentOutsideSpan(tree, declarator_span, object_span)) return null;

    const binding_span = tree.span(declarator.id);
    const binding_source = tree.source[binding_span.start..binding_span.end];
    const object_source = tree.source[object_span.start..object_span.end];
    return try std.fmt.allocPrint(allocator, "{{{s}}} = {s}", .{ binding_source, object_source });
}

fn hasCommentOutsideSpan(tree: *const ast.Tree, outer: ast.Span, inner: ast.Span) bool {
    for (tree.comments) |comment| {
        if (comment.span.end <= outer.start) continue;
        if (comment.span.start >= outer.end) break;
        if (comment.span.start < inner.start or comment.span.end > inner.end) return true;
    }
    return false;
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    kind: DestructuringKind,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        diagnosticMessage(kind),
        tree.span(index),
    );
}

fn preferredDestructuringKind(tree: *const ast.Tree, declarator: ast.VariableDeclarator, options: Options) ?DestructuringKind {
    if (declarator.init == .null) return null;

    const local_name = bindingIdentifierName(tree, declarator.id) orelse return null;

    const member = switch (tree.data(unwrapTransparent(tree, declarator.init))) {
        .member_expression => |member| member,
        else => return null,
    };
    if (member.optional) return null;

    if (isArrayIndexProperty(tree, member)) return .array;

    const property_name = propertyName(tree, member) orelse return null;
    return if (options.enforce_for_renamed_properties or std.mem.eql(u8, local_name, property_name)) .object else null;
}

fn preferredAssignmentDestructuringKind(tree: *const ast.Tree, expression: ast.AssignmentExpression, options: Options) ?DestructuringKind {
    const target_name = identifierReferenceName(tree, expression.left) orelse return null;

    const member = switch (tree.data(unwrapTransparent(tree, expression.right))) {
        .member_expression => |member| member,
        else => return null,
    };
    if (member.optional) return null;

    if (isArrayIndexProperty(tree, member)) return .array;

    const property_name = propertyName(tree, member) orelse return null;
    return if (options.enforce_for_renamed_properties or std.mem.eql(u8, target_name, property_name)) .object else null;
}

fn diagnosticMessage(kind: DestructuringKind) []const u8 {
    return switch (kind) {
        .object => "Use object destructuring.",
        .array => "Use array destructuring.",
    };
}

fn allowsVariableDeclarator(options: Options, kind: DestructuringKind) bool {
    return switch (kind) {
        .object => options.variable_declarator_object,
        .array => options.variable_declarator_array,
    };
}

fn allowsAssignmentExpression(options: Options, kind: DestructuringKind) bool {
    return switch (kind) {
        .object => options.assignment_expression_object,
        .array => options.assignment_expression_array,
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
