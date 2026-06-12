const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-inferrable-types";

pub fn checkVariableDeclarator(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
) Allocator.Error!void {
    if (declarator.init == .null) return;
    const type_annotation = bindingTypeAnnotation(tree, declarator.id);
    try reportInferrableType(allocator, diagnostics, tree, type_annotation, declarator.init);
}

pub fn checkAssignmentPattern(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    pattern: ast.AssignmentPattern,
) Allocator.Error!void {
    const type_annotation = if (pattern.type_annotation != .null)
        pattern.type_annotation
    else
        bindingTypeAnnotation(tree, pattern.left);

    try reportInferrableType(allocator, diagnostics, tree, type_annotation, pattern.right);
}

pub fn checkPropertyDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.PropertyDefinition,
) Allocator.Error!void {
    if (property.readonly or property.optional) return;
    if (property.value == .null) return;
    try reportInferrableType(allocator, diagnostics, tree, property.type_annotation, property.value);
}

fn reportInferrableType(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    type_annotation: ast.NodeIndex,
    value: ast.NodeIndex,
) Allocator.Error!void {
    const type_node = annotationType(tree, type_annotation);
    const type_name = inferrableType(tree, type_node, value) orelse return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(type_annotation),
        "Type {s} trivially inferred from a {s} literal, remove type annotation.",
        .{ type_name, type_name },
    );
}

fn inferrableType(tree: *const ast.Tree, type_node: ast.NodeIndex, value: ast.NodeIndex) ?[]const u8 {
    if (type_node == .null or value == .null) return null;

    return switch (tree.data(type_node)) {
        .ts_bigint_keyword => if (isBigIntValue(tree, value)) "bigint" else null,
        .ts_boolean_keyword => if (isBooleanValue(tree, value)) "boolean" else null,
        .ts_number_keyword => if (isNumberValue(tree, value)) "number" else null,
        .ts_null_keyword => if (isNullValue(tree, value)) "null" else null,
        .ts_string_keyword => if (isStringValue(tree, value)) "string" else null,
        .ts_symbol_keyword => if (isCallNamed(tree, value, "Symbol")) "symbol" else null,
        .ts_undefined_keyword => if (isUndefinedValue(tree, value)) "undefined" else null,
        .ts_type_reference => |reference| if (isTypeReferenceNamed(tree, reference, "RegExp") and isRegExpValue(tree, value)) "RegExp" else null,
        else => null,
    };
}

fn isBigIntValue(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const value = unwrapUnary(tree, index, .negate);
    return switch (tree.data(unwrapTransparent(tree, value))) {
        .bigint_literal => true,
        else => isCallNamed(tree, value, "BigInt"),
    };
}

fn isBooleanValue(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const value = unwrapTransparent(tree, index);
    return switch (tree.data(value)) {
        .boolean_literal => true,
        .unary_expression => |expression| expression.operator == .logical_not,
        else => isCallNamed(tree, value, "Boolean"),
    };
}

fn isNumberValue(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const value = unwrapUnary(tree, index, .positive);
    const unwrapped = unwrapUnary(tree, value, .negate);
    return switch (tree.data(unwrapTransparent(tree, unwrapped))) {
        .numeric_literal => true,
        .identifier_reference => |identifier| {
            const name = tree.string(identifier.name);
            return std.mem.eql(u8, name, "Infinity") or std.mem.eql(u8, name, "NaN");
        },
        else => isCallNamed(tree, unwrapped, "Number"),
    };
}

fn isNullValue(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .null_literal => true,
        else => false,
    };
}

fn isStringValue(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const value = unwrapTransparent(tree, index);
    return switch (tree.data(value)) {
        .string_literal => true,
        .template_literal => true,
        else => isCallNamed(tree, value, "String"),
    };
}

fn isUndefinedValue(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const value = unwrapTransparent(tree, index);
    return switch (tree.data(value)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), "undefined"),
        .unary_expression => |expression| expression.operator == .void,
        else => false,
    };
}

fn isRegExpValue(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const value = unwrapTransparent(tree, index);
    return switch (tree.data(value)) {
        .regexp_literal => true,
        .new_expression => |expression| isIdentifierReferenceNamed(tree, expression.callee, "RegExp"),
        else => isCallNamed(tree, value, "RegExp"),
    };
}

fn isCallNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    const value = unwrapTransparent(tree, index);
    return switch (tree.data(value)) {
        .call_expression => |expression| isIdentifierReferenceNamed(tree, expression.callee, name),
        else => false,
    };
}

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    const value = unwrapTransparent(tree, index);
    return switch (tree.data(value)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
    };
}

fn isTypeReferenceNamed(tree: *const ast.Tree, reference: ast.TSTypeReference, name: []const u8) bool {
    return isIdentifierReferenceNamed(tree, reference.type_name, name);
}

fn unwrapUnary(tree: *const ast.Tree, index: ast.NodeIndex, operator: ast.UnaryOperator) ast.NodeIndex {
    const value = unwrapTransparent(tree, index);
    return switch (tree.data(value)) {
        .unary_expression => |expression| if (expression.operator == operator) expression.argument else value,
        else => value,
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

fn annotationType(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    if (index == .null) return .null;
    return switch (tree.data(index)) {
        .ts_type_annotation => |annotation| annotation.type_annotation,
        else => .null,
    };
}

fn bindingTypeAnnotation(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    if (index == .null) return .null;
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| identifier.type_annotation,
        else => .null,
    };
}
