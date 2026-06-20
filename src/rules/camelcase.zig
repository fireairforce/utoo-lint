const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "camelcase";

pub const Properties = enum {
    always,
    never,
};

pub const Options = struct {
    properties: Properties = .always,
    ignore_destructuring: bool = false,
    ignore_imports: bool = false,
    ignore_globals: bool = false,
    allow: core.CamelcaseAllowPatterns = .{},
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
    try checkBinding(allocator, diagnostics, tree, declarator.id, options, false);
}

pub fn checkCatchClause(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    clause: ast.CatchClause,
    options: Options,
) Allocator.Error!void {
    try checkBinding(allocator, diagnostics, tree, clause.param, options, false);
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
    if (options.ignore_imports) return;
    try checkIdentifierNode(allocator, diagnostics, tree, specifier.local, options);
}

pub fn checkImportDefaultSpecifier(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    specifier: ast.ImportDefaultSpecifier,
    options: Options,
) Allocator.Error!void {
    if (options.ignore_imports) return;
    try checkIdentifierNode(allocator, diagnostics, tree, specifier.local, options);
}

pub fn checkImportNamespaceSpecifier(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    specifier: ast.ImportNamespaceSpecifier,
    options: Options,
) Allocator.Error!void {
    if (options.ignore_imports) return;
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
            .formal_parameter => |parameter| try checkBinding(allocator, diagnostics, tree, parameter.pattern, options, false),
            .ts_parameter_property => |property| try checkBinding(allocator, diagnostics, tree, property.parameter, options, false),
            else => {},
        }
    }
    try checkBinding(allocator, diagnostics, tree, params.rest, options, false);
}

fn checkBinding(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    options: Options,
    destructured: bool,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(index)) {
        .binding_identifier => if (!options.ignore_destructuring or !destructured) {
            try checkIdentifierNode(allocator, diagnostics, tree, index, options);
        },
        .assignment_pattern => |pattern| try checkBinding(allocator, diagnostics, tree, pattern.left, options, destructured),
        .binding_rest_element => |element| try checkBinding(allocator, diagnostics, tree, element.argument, options, destructured),
        .array_pattern => |pattern| {
            for (tree.extra(pattern.elements)) |element| {
                try checkBinding(allocator, diagnostics, tree, element, options, true);
            }
            try checkBinding(allocator, diagnostics, tree, pattern.rest, options, true);
        },
        .object_pattern => |pattern| {
            for (tree.extra(pattern.properties)) |property_index| {
                const property = switch (tree.data(property_index)) {
                    .binding_property => |property| property,
                    else => continue,
                };
                try checkBinding(allocator, diagnostics, tree, property.value, options, true);
            }
            try checkBinding(allocator, diagnostics, tree, pattern.rest, options, true);
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
    try report(allocator, diagnostics, tree, index, identifier);
}

fn isAllowed(name: []const u8, options: Options) bool {
    if (!hasDisallowedUnderscore(name)) return true;
    if (isUppercaseConstant(name)) return true;
    if (options.allow.matches(name)) return true;
    return false;
}

fn hasDisallowedUnderscore(name: []const u8) bool {
    const trimmed = std.mem.trim(u8, name, "_");
    return std.mem.indexOfScalar(u8, trimmed, '_') != null;
}

fn isUppercaseConstant(name: []const u8) bool {
    const trimmed = std.mem.trim(u8, name, "_");
    var has_alpha = false;
    for (trimmed) |char| {
        if (std.ascii.isAlphabetic(char)) {
            has_alpha = true;
            if (std.ascii.isLower(char)) return false;
        }
    }
    return has_alpha;
}

fn identifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?Identifier {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .identifier_name => |identifier| .{ .name = tree.string(identifier.name) },
        .binding_identifier => |identifier| .{ .name = tree.string(identifier.name) },
        .private_identifier => |identifier| .{ .name = tree.string(identifier.name), .private = true },
        else => null,
    };
}

fn report(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    identifier: Identifier,
) Allocator.Error!void {
    if (identifier.private) {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "Identifier '#{s}' is not in camel case.",
            .{identifier.name},
        );
    } else {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "Identifier '{s}' is not in camel case.",
            .{identifier.name},
        );
    }
}
