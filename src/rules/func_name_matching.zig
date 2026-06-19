const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "func-name-matching";

pub const Style = enum {
    always,
    never,
};

pub const Options = struct {
    style: Style = .always,
    include_commonjs_module_exports: bool = false,
    consider_property_descriptor: bool = false,
};

pub fn checkVariableDeclarator(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
) Allocator.Error!void {
    if (declarator.init == .null) return;

    const target = bindingIdentifierName(tree, declarator.id) orelse return;
    try checkFunctionName(allocator, diagnostics, tree, declarator.init, target, .{});
}

pub fn checkVariableDeclaratorWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
    options: Options,
) Allocator.Error!void {
    if (declarator.init == .null) return;

    const target = bindingIdentifierName(tree, declarator.id) orelse return;
    try checkFunctionName(allocator, diagnostics, tree, declarator.init, target, options);
}

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
) Allocator.Error!void {
    if (expression.operator != .assign) return;

    const target = assignmentTargetName(tree, expression.left) orelse return;
    try checkFunctionName(allocator, diagnostics, tree, expression.right, target, .{});
}

pub fn checkAssignmentExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    options: Options,
) Allocator.Error!void {
    if (expression.operator != .assign) return;

    const target = assignmentTargetName(tree, expression.left, options) orelse return;
    try checkFunctionName(allocator, diagnostics, tree, expression.right, target, options);
}

pub fn checkCallExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    options: Options,
) Allocator.Error!void {
    if (!options.consider_property_descriptor) return;

    const arguments = tree.extra(call.arguments);
    if (isStaticMemberCall(tree, call.callee, "Object", "defineProperty") or
        isStaticMemberCall(tree, call.callee, "Reflect", "defineProperty"))
    {
        if (arguments.len < 3) return;
        const target = propertyNameFromArgument(tree, arguments[1]) orelse return;
        try checkPropertyDescriptor(allocator, diagnostics, tree, arguments[2], target, options);
        return;
    }

    if (isStaticMemberCall(tree, call.callee, "Object", "defineProperties") or
        isStaticMemberCall(tree, call.callee, "Object", "create"))
    {
        if (arguments.len < 2) return;
        try checkNestedPropertyDescriptors(allocator, diagnostics, tree, arguments[1], options);
    }
}

pub fn checkObjectProperty(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.ObjectProperty,
) Allocator.Error!void {
    if (property.method or property.value == .null) return;

    const target = propertyName(tree, property.key, property.computed) orelse return;
    try checkFunctionName(allocator, diagnostics, tree, property.value, target, .{});
}

pub fn checkObjectPropertyWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.ObjectProperty,
    options: Options,
) Allocator.Error!void {
    if (property.method or property.value == .null) return;

    const target = propertyName(tree, property.key, property.computed) orelse return;
    try checkFunctionName(allocator, diagnostics, tree, property.value, target, options);
}

pub fn checkObjectPropertyWithContextOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.ObjectProperty,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (isPropertyDescriptorValueProperty(tree, property, index, ctx)) return;
    try checkObjectPropertyWithOptions(allocator, diagnostics, tree, property, options);
}

pub fn checkPropertyDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.PropertyDefinition,
) Allocator.Error!void {
    if (property.value == .null) return;

    const target = propertyName(tree, property.key, property.computed) orelse return;
    try checkFunctionName(allocator, diagnostics, tree, property.value, target, .{});
}

pub fn checkPropertyDefinitionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.PropertyDefinition,
    options: Options,
) Allocator.Error!void {
    if (property.value == .null) return;

    const target = propertyName(tree, property.key, property.computed) orelse return;
    try checkFunctionName(allocator, diagnostics, tree, property.value, target, options);
}

fn checkFunctionName(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    value: ast.NodeIndex,
    target: []const u8,
    options: Options,
) Allocator.Error!void {
    const function = switch (tree.data(unwrapTransparent(tree, value))) {
        .function => |function| function,
        else => return,
    };
    if (function.type != .function_expression) return;

    const actual = bindingIdentifierName(tree, function.id) orelse return;
    const matches = std.mem.eql(u8, actual, target);
    if (matches == (options.style == .always)) return;

    switch (options.style) {
        .always => try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(value),
            "Function name `{s}` should match target name `{s}`.",
            .{ actual, target },
        ),
        .never => try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(value),
            "Function name `{s}` should not match target name `{s}`.",
            .{ actual, target },
        ),
    }
}

fn checkNestedPropertyDescriptors(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    descriptors_index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    const descriptors = switch (tree.data(descriptors_index)) {
        .object_expression => |object| object,
        else => return,
    };

    for (tree.extra(descriptors.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        if (property.value == .null) continue;

        const target = propertyName(tree, property.key, property.computed) orelse continue;
        try checkPropertyDescriptor(allocator, diagnostics, tree, property.value, target, options);
    }
}

fn checkPropertyDescriptor(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    descriptor_index: ast.NodeIndex,
    target: []const u8,
    options: Options,
) Allocator.Error!void {
    const descriptor = switch (tree.data(descriptor_index)) {
        .object_expression => |object| object,
        else => return,
    };

    for (tree.extra(descriptor.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        if (property.value == .null or !propertyKeyEquals(tree, property, "value")) continue;
        try checkFunctionName(allocator, diagnostics, tree, property.value, target, options);
    }
}

fn assignmentTargetName(tree: *const ast.Tree, index: ast.NodeIndex, options: Options) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .member_expression => |member| memberTargetName(tree, member, options),
        else => null,
    };
}

fn memberTargetName(tree: *const ast.Tree, member: ast.MemberExpression, options: Options) ?[]const u8 {
    if (isModuleExportsTarget(tree, member) and !options.include_commonjs_module_exports) return null;
    return propertyName(tree, member.property, member.computed);
}

fn isModuleExportsTarget(tree: *const ast.Tree, member: ast.MemberExpression) bool {
    const name = propertyName(tree, member.property, member.computed) orelse return false;
    return isIdentifierReferenceNamed(tree, member.object, "module") and
        std.mem.eql(u8, name, "exports");
}

fn propertyName(tree: *const ast.Tree, key: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (key == .null) return null;

    return if (computed)
        switch (tree.data(unwrapTransparent(tree, key))) {
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

fn propertyNameFromArgument(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
        .template_literal => |literal| templateStringValue(tree, literal),
        else => null,
    };
}

fn propertyKeyEquals(tree: *const ast.Tree, property: ast.ObjectProperty, name: []const u8) bool {
    if (property.computed) return false;
    if (property.key == .null) return false;

    return switch (tree.data(property.key)) {
        .identifier_name => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        .string_literal => |literal| std.mem.eql(u8, tree.string(literal.value), name),
        else => false,
    };
}

fn isPropertyDescriptorValueProperty(
    tree: *const ast.Tree,
    property: ast.ObjectProperty,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) bool {
    if (index == .null or property.value == .null or !propertyKeyEquals(tree, property, "value")) return false;

    const descriptor_object = ctx.path.ancestor(1) orelse return false;
    return isDefinePropertyDescriptorObject(tree, ctx, descriptor_object) or
        isNestedPropertyDescriptorObject(tree, ctx, descriptor_object);
}

fn isDefinePropertyDescriptorObject(
    tree: *const ast.Tree,
    ctx: *traverser.basic.Ctx,
    descriptor_object: ast.NodeIndex,
) bool {
    const call_index = ctx.path.ancestor(2) orelse return false;
    const call = switch (tree.data(call_index)) {
        .call_expression => |call| call,
        else => return false,
    };

    const arguments = tree.extra(call.arguments);
    if (arguments.len < 3 or arguments[2] != descriptor_object) return false;
    return isStaticMemberCall(tree, call.callee, "Object", "defineProperty") or
        isStaticMemberCall(tree, call.callee, "Reflect", "defineProperty");
}

fn isNestedPropertyDescriptorObject(
    tree: *const ast.Tree,
    ctx: *traverser.basic.Ctx,
    descriptor_object: ast.NodeIndex,
) bool {
    const property_index = ctx.path.ancestor(2) orelse return false;
    const property = switch (tree.data(property_index)) {
        .object_property => |property| property,
        else => return false,
    };
    if (property.value != descriptor_object) return false;

    const descriptors_object = ctx.path.ancestor(3) orelse return false;
    const call_index = ctx.path.ancestor(4) orelse return false;
    const call = switch (tree.data(call_index)) {
        .call_expression => |call| call,
        else => return false,
    };

    const arguments = tree.extra(call.arguments);
    if (arguments.len < 2 or arguments[1] != descriptors_object) return false;
    return isStaticMemberCall(tree, call.callee, "Object", "defineProperties") or
        isStaticMemberCall(tree, call.callee, "Object", "create");
}

fn isStaticMemberCall(tree: *const ast.Tree, callee: ast.NodeIndex, object_name: []const u8, property_name: []const u8) bool {
    const member = switch (tree.data(unwrapTransparent(tree, callee))) {
        .member_expression => |member| member,
        else => return false,
    };

    const property = staticMemberPropertyName(tree, member) orelse return false;
    return isIdentifierReferenceNamed(tree, member.object, object_name) and
        std.mem.eql(u8, property, property_name);
}

fn staticMemberPropertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;

    return switch (tree.data(member.property)) {
        .identifier_name => |identifier| if (member.computed) null else tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .template_literal => |literal| templateStringValue(tree, literal),
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
