const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/typedef";

pub fn checkFunctionParameters(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
) Allocator.Error!void {
    try checkParameters(allocator, diagnostics, tree, function.params);
}

pub fn checkArrowFunctionParameters(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ArrowFunctionExpression,
) Allocator.Error!void {
    try checkParameters(allocator, diagnostics, tree, expression.params);
}

pub fn checkPropertySignature(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    signature: ast.TSPropertySignature,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (signature.type_annotation != .null) return;

    if (propertyName(tree, signature.key)) |name| {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .@"error",
            id,
            tree.span(index),
            "Expected {s} to have a type annotation.",
            .{name},
        );
        return;
    }

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Expected a type annotation.",
        tree.span(index),
    );
}

pub fn checkPropertyDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.PropertyDefinition,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (property.type_annotation != .null) return;

    if (propertyName(tree, property.key)) |name| {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .@"error",
            id,
            tree.span(index),
            "Expected {s} to have a type annotation.",
            .{name},
        );
        return;
    }

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Expected a type annotation.",
        tree.span(index),
    );
}

fn checkParameters(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    params_index: ast.NodeIndex,
) Allocator.Error!void {
    const parameters = switch (tree.data(params_index)) {
        .formal_parameters => |params| params,
        else => return,
    };

    for (tree.extra(parameters.items)) |parameter_index| {
        const pattern = parameterPattern(tree, parameter_index) orelse continue;
        if (hasTypeAnnotation(tree, pattern)) continue;

        if (bindingName(tree, pattern)) |name| {
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .@"error",
                id,
                tree.span(pattern),
                "Expected {s} to have a type annotation.",
                .{name},
            );
            continue;
        }

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .@"error",
            id,
            "Expected a type annotation.",
            tree.span(pattern),
        );
    }
}

fn parameterPattern(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.NodeIndex {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .formal_parameter => |parameter| parameter.pattern,
        .ts_parameter_property => |property| property.parameter,
        else => null,
    };
}

fn hasTypeAnnotation(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return true;
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| identifier.type_annotation != .null,
        .assignment_pattern => |pattern| pattern.type_annotation != .null or hasTypeAnnotation(tree, pattern.left),
        .binding_rest_element => |element| element.type_annotation != .null or hasTypeAnnotation(tree, element.argument),
        .array_pattern => |pattern| pattern.type_annotation != .null,
        .object_pattern => |pattern| pattern.type_annotation != .null,
        .ts_this_parameter => |parameter| parameter.type_annotation != .null,
        else => true,
    };
}

fn bindingName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        .assignment_pattern => |pattern| bindingName(tree, pattern.left),
        .binding_rest_element => |element| bindingName(tree, element.argument),
        else => null,
    };
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
        .private_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}
