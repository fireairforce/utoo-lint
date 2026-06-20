const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "id-length";

pub const Options = struct {
    min: usize = 2,
    has_max: bool = false,
    max: usize = 0,
    properties: core.IdLengthProperties = .always,
    exceptions: core.IdLengthExceptions = .{},
    exception_patterns: core.IdLengthExceptionPatterns = .{},
};

const Identifier = struct {
    name: []const u8,
    private: bool = false,
};

pub fn checkClass(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    class: ast.Class,
    options: Options,
) Allocator.Error!void {
    try checkIdentifierNode(allocator, diagnostics, tree, class.id, options);
}

pub fn checkFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
    options: Options,
) Allocator.Error!void {
    try checkIdentifierNode(allocator, diagnostics, tree, function.id, options);
    try checkFormalParameters(allocator, diagnostics, tree, function.params, options);
}

pub fn checkArrowFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ArrowFunctionExpression,
    options: Options,
) Allocator.Error!void {
    try checkFormalParameters(allocator, diagnostics, tree, expression.params, options);
}

pub fn checkVariableDeclarator(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
    options: Options,
) Allocator.Error!void {
    try checkBinding(allocator, diagnostics, tree, declarator.id, options);
}

pub fn checkCatchClause(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    clause: ast.CatchClause,
    options: Options,
) Allocator.Error!void {
    try checkBinding(allocator, diagnostics, tree, clause.param, options);
}

pub fn checkObjectProperty(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.ObjectProperty,
    options: Options,
) Allocator.Error!void {
    if (options.properties == .never or property.computed) return;
    try checkIdentifierNode(allocator, diagnostics, tree, property.key, options);
}

pub fn checkMethodDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    method: ast.MethodDefinition,
    options: Options,
) Allocator.Error!void {
    if (options.properties == .never or method.computed) return;
    try checkIdentifierNode(allocator, diagnostics, tree, method.key, options);
}

pub fn checkPropertyDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.PropertyDefinition,
    options: Options,
) Allocator.Error!void {
    if (options.properties == .never or property.computed) return;
    try checkIdentifierNode(allocator, diagnostics, tree, property.key, options);
}

pub fn checkImportSpecifier(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    specifier: ast.ImportSpecifier,
    options: Options,
) Allocator.Error!void {
    if (specifier.imported == specifier.local) return;
    try checkIdentifierNode(allocator, diagnostics, tree, specifier.local, options);
}

pub fn checkImportDefaultSpecifier(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    specifier: ast.ImportDefaultSpecifier,
    options: Options,
) Allocator.Error!void {
    try checkIdentifierNode(allocator, diagnostics, tree, specifier.local, options);
}

pub fn checkImportNamespaceSpecifier(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    specifier: ast.ImportNamespaceSpecifier,
    options: Options,
) Allocator.Error!void {
    try checkIdentifierNode(allocator, diagnostics, tree, specifier.local, options);
}

fn checkFormalParameters(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    params_index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (params_index == .null) return;

    const params = switch (tree.data(params_index)) {
        .formal_parameters => |params| params,
        else => return,
    };

    for (tree.extra(params.items)) |item_index| {
        switch (tree.data(item_index)) {
            .formal_parameter => |parameter| try checkBinding(allocator, diagnostics, tree, parameter.pattern, options),
            .ts_parameter_property => |property| try checkBinding(allocator, diagnostics, tree, property.parameter, options),
            else => {},
        }
    }
    try checkBinding(allocator, diagnostics, tree, params.rest, options);
}

fn checkBinding(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(index)) {
        .binding_identifier => try checkIdentifierNode(allocator, diagnostics, tree, index, options),
        .assignment_pattern => |pattern| try checkBinding(allocator, diagnostics, tree, pattern.left, options),
        .binding_rest_element => |element| try checkBinding(allocator, diagnostics, tree, element.argument, options),
        .array_pattern => |pattern| {
            for (tree.extra(pattern.elements)) |element| {
                try checkBinding(allocator, diagnostics, tree, element, options);
            }
            try checkBinding(allocator, diagnostics, tree, pattern.rest, options);
        },
        .object_pattern => |pattern| {
            for (tree.extra(pattern.properties)) |property_index| {
                const property = switch (tree.data(property_index)) {
                    .binding_property => |property| property,
                    else => continue,
                };
                try checkBinding(allocator, diagnostics, tree, property.value, options);
            }
            try checkBinding(allocator, diagnostics, tree, pattern.rest, options);
        },
        else => {},
    }
}

fn checkIdentifierNode(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (index == .null) return;
    const identifier = identifierName(tree, index) orelse return;
    if (isAllowed(identifier.name, options)) return;

    if (identifier.name.len < options.min) {
        try report(allocator, diagnostics, tree, index, identifier, .min, options.min);
        return;
    }
    if (options.has_max and identifier.name.len > options.max) {
        try report(allocator, diagnostics, tree, index, identifier, .max, options.max);
    }
}

const LimitKind = enum { min, max };

fn report(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    identifier: Identifier,
    kind: LimitKind,
    limit: usize,
) Allocator.Error!void {
    const span = tree.span(index);
    switch (kind) {
        .min => if (identifier.private) {
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .warning,
                id,
                span,
                "Identifier name '#{s}' is too short (< {d}).",
                .{ identifier.name, limit },
            );
        } else {
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .warning,
                id,
                span,
                "Identifier name '{s}' is too short (< {d}).",
                .{ identifier.name, limit },
            );
        },
        .max => if (identifier.private) {
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .warning,
                id,
                span,
                "Identifier name '#{s}' is too long (> {d}).",
                .{ identifier.name, limit },
            );
        } else {
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .warning,
                id,
                span,
                "Identifier name '{s}' is too long (> {d}).",
                .{ identifier.name, limit },
            );
        },
    }
}

fn identifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?Identifier {
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| .{ .name = tree.string(identifier.name) },
        .identifier_name => |identifier| .{ .name = tree.string(identifier.name) },
        .private_identifier => |identifier| .{ .name = tree.string(identifier.name), .private = true },
        else => null,
    };
}

fn isAllowed(name: []const u8, options: Options) bool {
    return options.exceptions.contains(name) or options.exception_patterns.matches(name);
}
