const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "func-name-matching";

pub fn checkVariableDeclarator(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
) Allocator.Error!void {
    if (declarator.init == .null) return;

    const target = bindingIdentifierName(tree, declarator.id) orelse return;
    try checkFunctionName(allocator, diagnostics, tree, declarator.init, target);
}

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
) Allocator.Error!void {
    if (expression.operator != .assign) return;

    const target = assignmentTargetName(tree, expression.left) orelse return;
    try checkFunctionName(allocator, diagnostics, tree, expression.right, target);
}

pub fn checkObjectProperty(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.ObjectProperty,
) Allocator.Error!void {
    if (property.method or property.value == .null) return;

    const target = propertyName(tree, property.key, property.computed) orelse return;
    try checkFunctionName(allocator, diagnostics, tree, property.value, target);
}

pub fn checkPropertyDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.PropertyDefinition,
) Allocator.Error!void {
    if (property.value == .null) return;

    const target = propertyName(tree, property.key, property.computed) orelse return;
    try checkFunctionName(allocator, diagnostics, tree, property.value, target);
}

fn checkFunctionName(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    value: ast.NodeIndex,
    target: []const u8,
) Allocator.Error!void {
    const function = switch (tree.data(unwrapTransparent(tree, value))) {
        .function => |function| function,
        else => return,
    };
    if (function.type != .function_expression) return;

    const actual = bindingIdentifierName(tree, function.id) orelse return;
    if (std.mem.eql(u8, actual, target)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(value),
        "Function name `{s}` should match target name `{s}`.",
        .{ actual, target },
    );
}

fn assignmentTargetName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .member_expression => |member| memberTargetName(tree, member),
        else => null,
    };
}

fn memberTargetName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (isCommonJsExportTarget(tree, member)) return null;
    return propertyName(tree, member.property, member.computed);
}

fn isCommonJsExportTarget(tree: *const ast.Tree, member: ast.MemberExpression) bool {
    if (isIdentifierReferenceNamed(tree, member.object, "exports")) return true;
    if (!member.computed and
        isIdentifierReferenceNamed(tree, member.object, "module") and
        propertyName(tree, member.property, member.computed) != null and
        std.mem.eql(u8, propertyName(tree, member.property, member.computed).?, "exports"))
    {
        return true;
    }

    const object = switch (tree.data(unwrapTransparent(tree, member.object))) {
        .member_expression => |object| object,
        else => return false,
    };
    if (object.computed) return false;

    return isIdentifierReferenceNamed(tree, object.object, "module") and
        propertyName(tree, object.property, object.computed) != null and
        std.mem.eql(u8, propertyName(tree, object.property, object.computed).?, "exports");
}

fn propertyName(tree: *const ast.Tree, key: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (key == .null) return null;

    return if (computed)
        switch (tree.data(unwrapTransparent(tree, key))) {
            .identifier_reference => |identifier| tree.string(identifier.name),
            .string_literal => |literal| tree.string(literal.value),
            .numeric_literal => |literal| tree.string(literal.raw),
            else => null,
        }
    else switch (tree.data(key)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
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

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    if (index == .null) return false;
    return switch (tree.data(unwrapTransparent(tree, index))) {
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
