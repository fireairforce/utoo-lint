const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-shadow-restricted-names";

pub fn checkFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
) Allocator.Error!void {
    try checkBinding(allocator, diagnostics, tree, function.id, false);
    try checkFormalParameters(allocator, diagnostics, tree, function.params);
}

pub fn checkFormalParameters(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    params_index: ast.NodeIndex,
) Allocator.Error!void {
    if (params_index == .null) return;

    const params = switch (tree.data(params_index)) {
        .formal_parameters => |params| params,
        else => return,
    };

    for (tree.extra(params.items)) |item_index| {
        switch (tree.data(item_index)) {
            .formal_parameter => |parameter| try checkBinding(allocator, diagnostics, tree, parameter.pattern, false),
            .ts_parameter_property => |property| try checkBinding(allocator, diagnostics, tree, property.parameter, false),
            else => {},
        }
    }

    try checkBinding(allocator, diagnostics, tree, params.rest, false);
}

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

        try checkBinding(allocator, diagnostics, tree, declarator.id, declarator.init == .null);
    }
}

pub fn checkBinding(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    allow_uninitialized_undefined: bool,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(index)) {
        .binding_identifier => |identifier| try checkIdentifier(
            allocator,
            diagnostics,
            tree,
            identifier,
            index,
            allow_uninitialized_undefined,
        ),
        .assignment_pattern => |pattern| try checkBinding(allocator, diagnostics, tree, pattern.left, false),
        .binding_rest_element => |element| try checkBinding(allocator, diagnostics, tree, element.argument, false),
        .array_pattern => |pattern| {
            for (tree.extra(pattern.elements)) |element| {
                try checkBinding(allocator, diagnostics, tree, element, false);
            }
            try checkBinding(allocator, diagnostics, tree, pattern.rest, false);
        },
        .object_pattern => |pattern| {
            for (tree.extra(pattern.properties)) |property_index| {
                const property = switch (tree.data(property_index)) {
                    .binding_property => |property| property,
                    else => continue,
                };
                try checkBinding(allocator, diagnostics, tree, property.value, false);
            }
            try checkBinding(allocator, diagnostics, tree, pattern.rest, false);
        },
        else => {},
    }
}

fn checkIdentifier(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    identifier: ast.BindingIdentifier,
    index: ast.NodeIndex,
    allow_uninitialized_undefined: bool,
) Allocator.Error!void {
    const name = tree.string(identifier.name);
    if (allow_uninitialized_undefined and std.mem.eql(u8, name, "undefined")) return;
    if (!isRestrictedName(name)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Do not shadow the restricted name '{s}'.",
        .{name},
    );
}

fn isRestrictedName(name: []const u8) bool {
    return std.mem.eql(u8, name, "undefined") or
        std.mem.eql(u8, name, "NaN") or
        std.mem.eql(u8, name, "Infinity") or
        std.mem.eql(u8, name, "arguments") or
        std.mem.eql(u8, name, "eval") or
        std.mem.eql(u8, name, "globalThis");
}
