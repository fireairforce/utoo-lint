const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "prefer-rest-params";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (function.body == .null) return;
    if (hasRestParameter(tree, function.params)) return;
    if (bindingNamed(tree, function.id, "arguments")) return;
    if (paramsContainBinding(tree, function.params, "arguments")) return;
    if (bodyDeclaresArguments(tree, function.body)) return;
    if (!bodyUsesArguments(tree, function.body)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Use the rest parameters instead of 'arguments'.",
        tree.span(index),
    );
}

fn hasRestParameter(tree: *const ast.Tree, params_index: ast.NodeIndex) bool {
    const params = formalParameters(tree, params_index) orelse return false;
    return params.rest != .null;
}

fn paramsContainBinding(tree: *const ast.Tree, params_index: ast.NodeIndex, name: []const u8) bool {
    const params = formalParameters(tree, params_index) orelse return false;

    for (tree.extra(params.items)) |item_index| {
        switch (tree.data(item_index)) {
            .formal_parameter => |parameter| if (bindingNamed(tree, parameter.pattern, name)) return true,
            .ts_parameter_property => |property| if (bindingNamed(tree, property.parameter, name)) return true,
            else => {},
        }
    }

    return bindingNamed(tree, params.rest, name);
}

fn formalParameters(tree: *const ast.Tree, params_index: ast.NodeIndex) ?ast.FormalParameters {
    if (params_index == .null) return null;
    return switch (tree.data(params_index)) {
        .formal_parameters => |params| params,
        else => null,
    };
}

fn bodyDeclaresArguments(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .variable_declaration => |declaration| {
            for (tree.extra(declaration.declarators)) |declarator_index| {
                const declarator = switch (tree.data(declarator_index)) {
                    .variable_declarator => |declarator| declarator,
                    else => continue,
                };
                if (bindingNamed(tree, declarator.id, "arguments")) return true;
            }
            return false;
        },
        .function => |function| function.type == .function_declaration and bindingNamed(tree, function.id, "arguments"),
        .arrow_function_expression => false,
        inline else => |node| nodeDeclaresArguments(tree, node),
    };
}

fn nodeDeclaresArguments(tree: *const ast.Tree, node: anytype) bool {
    const T = @TypeOf(node);
    if (@typeInfo(T) != .@"struct") return false;

    inline for (@typeInfo(T).@"struct".fields) |field| {
        if (field.type == ast.NodeIndex) {
            if (bodyDeclaresArguments(tree, @field(node, field.name))) return true;
        } else if (field.type == ast.IndexRange) {
            for (tree.extra(@field(node, field.name))) |child| {
                if (bodyDeclaresArguments(tree, child)) return true;
            }
        }
    }

    return false;
}

fn bodyUsesArguments(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), "arguments"),
        .function,
        .arrow_function_expression,
        => false,
        inline else => |node| nodeUsesArguments(tree, node),
    };
}

fn nodeUsesArguments(tree: *const ast.Tree, node: anytype) bool {
    const T = @TypeOf(node);
    if (@typeInfo(T) != .@"struct") return false;

    inline for (@typeInfo(T).@"struct".fields) |field| {
        if (field.type == ast.NodeIndex) {
            if (bodyUsesArguments(tree, @field(node, field.name))) return true;
        } else if (field.type == ast.IndexRange) {
            for (tree.extra(@field(node, field.name))) |child| {
                if (bodyUsesArguments(tree, child)) return true;
            }
        }
    }

    return false;
}

fn bindingNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .binding_identifier => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        .formal_parameter => |parameter| bindingNamed(tree, parameter.pattern, name),
        .assignment_pattern => |pattern| bindingNamed(tree, pattern.left, name),
        .binding_rest_element => |element| bindingNamed(tree, element.argument, name),
        .array_pattern => |pattern| {
            for (tree.extra(pattern.elements)) |element| {
                if (bindingNamed(tree, element, name)) return true;
            }
            return bindingNamed(tree, pattern.rest, name);
        },
        .object_pattern => |pattern| {
            for (tree.extra(pattern.properties)) |property_index| {
                const property = switch (tree.data(property_index)) {
                    .binding_property => |property| property,
                    else => continue,
                };
                if (bindingNamed(tree, property.value, name)) return true;
            }
            return bindingNamed(tree, pattern.rest, name);
        },
        else => false,
    };
}
