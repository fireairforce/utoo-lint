const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-underscore-dangle";

pub const Options = struct {
    allow: core.NoShadowAllowNames = .{},
    allow_after_this: bool = false,
    allow_after_super: bool = false,
    allow_after_this_constructor: bool = false,
    allow_function_params: bool = true,
    allow_in_array_destructuring: bool = true,
    allow_in_object_destructuring: bool = true,
    enforce_in_method_names: bool = false,
    enforce_in_class_fields: bool = false,
};

pub fn checkVariableDeclarator(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
) Allocator.Error!void {
    return checkVariableDeclaratorWithOptions(allocator, diagnostics, tree, declarator, .{});
}

pub fn checkVariableDeclaratorWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
    options: Options,
) Allocator.Error!void {
    switch (tree.data(declarator.id)) {
        .binding_identifier => |identifier| try checkName(allocator, diagnostics, tree, declarator.id, tree.string(identifier.name), false, options),
        .array_pattern => {
            if (!options.allow_in_array_destructuring) {
                try checkBinding(allocator, diagnostics, tree, declarator.id, options);
            }
        },
        .object_pattern => {
            if (!options.allow_in_object_destructuring) {
                try checkBinding(allocator, diagnostics, tree, declarator.id, options);
            }
        },
        else => {},
    }
}

pub fn checkFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
) Allocator.Error!void {
    return checkFunctionWithOptions(allocator, diagnostics, tree, function, .{});
}

pub fn checkFunctionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
    options: Options,
) Allocator.Error!void {
    if (function.id != .null) {
        if (bindingName(tree, function.id)) |name| {
            try checkName(allocator, diagnostics, tree, function.id, name, false, options);
        }
    }
    try checkFormalParametersWithOptions(allocator, diagnostics, tree, function.params, options);
}

pub fn checkFormalParametersWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    params_index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (options.allow_function_params) return;

    const params = formalParameters(tree, params_index) orelse return;
    for (tree.extra(params.items)) |item_index| {
        switch (tree.data(item_index)) {
            .formal_parameter => |parameter| try checkBinding(allocator, diagnostics, tree, parameter.pattern, options),
            .ts_parameter_property => |property| try checkBinding(allocator, diagnostics, tree, property.parameter, options),
            else => {},
        }
    }

    try checkBinding(allocator, diagnostics, tree, params.rest, options);
}

pub fn checkClass(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    class: ast.Class,
) Allocator.Error!void {
    return checkClassWithOptions(allocator, diagnostics, tree, class, .{});
}

pub fn checkClassWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    class: ast.Class,
    options: Options,
) Allocator.Error!void {
    if (class.id == .null) return;

    const name = bindingName(tree, class.id) orelse return;
    try checkName(allocator, diagnostics, tree, class.id, name, false, options);
}

pub fn checkMemberExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
) Allocator.Error!void {
    return checkMemberExpressionWithOptions(allocator, diagnostics, tree, member, .{});
}

pub fn checkMemberExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
    options: Options,
) Allocator.Error!void {
    if (member.computed) return;

    const name = propertyName(tree, member) orelse return;
    if (isAllowedMemberAccess(tree, member, options)) return;
    try checkName(allocator, diagnostics, tree, member.property, name, true, options);
}

pub fn checkMethodDefinitionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    method: ast.MethodDefinition,
    options: Options,
) Allocator.Error!void {
    if (!options.enforce_in_method_names) return;

    const name = staticName(tree, method.key, method.computed) orelse return;
    try checkName(allocator, diagnostics, tree, method.key, name, false, options);
}

pub fn checkObjectPropertyWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.ObjectProperty,
    options: Options,
) Allocator.Error!void {
    if (!options.enforce_in_method_names) return;
    if (!property.method and property.kind == .init) return;

    const name = staticName(tree, property.key, property.computed) orelse return;
    try checkName(allocator, diagnostics, tree, property.key, name, false, options);
}

pub fn checkPropertyDefinitionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.PropertyDefinition,
    options: Options,
) Allocator.Error!void {
    if (!options.enforce_in_class_fields) return;

    const name = staticName(tree, property.key, property.computed) orelse return;
    try checkName(allocator, diagnostics, tree, property.key, name, false, options);
}

fn isAllowedMemberAccess(tree: *const ast.Tree, member: ast.MemberExpression, options: Options) bool {
    if (options.allow_after_this and isThisExpression(tree, member.object)) return true;
    if (options.allow_after_super and isSuperExpression(tree, member.object)) return true;
    if (options.allow_after_this_constructor and isThisConstructorExpression(tree, member.object)) return true;
    return false;
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
        .binding_identifier => |identifier| try checkName(allocator, diagnostics, tree, index, tree.string(identifier.name), false, options),
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

fn checkName(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    node: ast.NodeIndex,
    name: []const u8,
    allow_proto: bool,
    options: Options,
) Allocator.Error!void {
    if (!hasDanglingUnderscore(name)) return;
    if (isAllowedName(name, allow_proto, options)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(node),
        "Unexpected dangling '_' in '{s}'.",
        .{name},
    );
}

fn hasDanglingUnderscore(name: []const u8) bool {
    if (name.len == 0) return false;
    return name[0] == '_' or name[name.len - 1] == '_';
}

fn isAllowedName(name: []const u8, allow_proto: bool, options: Options) bool {
    if (options.allow.contains(name)) return true;
    if (std.mem.eql(u8, name, "_")) return true;
    if (std.mem.eql(u8, name, "__dirname")) return true;
    if (std.mem.eql(u8, name, "__filename")) return true;
    return allow_proto and std.mem.eql(u8, name, "__proto__");
}

fn bindingName(tree: *const ast.Tree, node: ast.NodeIndex) ?[]const u8 {
    if (node == .null) return null;

    return switch (tree.data(node)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn formalParameters(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.FormalParameters {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .formal_parameters => |params| params,
        else => null,
    };
}

fn propertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;

    return switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn staticName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (index == .null or computed) return null;

    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .private_identifier => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn isThisExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .this_expression => true,
        else => false,
    };
}

fn isSuperExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .super => true,
        else => false,
    };
}

fn isThisConstructorExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const unwrapped = unwrapTransparent(tree, index);
    return switch (tree.data(unwrapped)) {
        .member_expression => |member| isThisExpression(tree, member.object) and isPropertyNamed(tree, member, "constructor"),
        else => false,
    };
}

fn isPropertyNamed(tree: *const ast.Tree, member: ast.MemberExpression, expected: []const u8) bool {
    const name = propertyName(tree, member) orelse return false;
    return std.mem.eql(u8, name, expected);
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
