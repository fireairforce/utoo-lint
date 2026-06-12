const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-param-reassign";

const ParamSet = std.StringHashMapUnmanaged(void);

pub fn checkFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
) Allocator.Error!void {
    var params: ParamSet = .empty;
    defer params.deinit(allocator);

    try collectFormalParameters(allocator, tree, function.params, &params);
    if (params.size == 0 or function.body == .null) return;

    try scanNode(allocator, diagnostics, tree, &params, function.body);
}

pub fn checkArrowFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ArrowFunctionExpression,
) Allocator.Error!void {
    var params: ParamSet = .empty;
    defer params.deinit(allocator);

    try collectFormalParameters(allocator, tree, expression.params, &params);
    if (params.size == 0) return;

    try scanNode(allocator, diagnostics, tree, &params, expression.body);
}

fn collectFormalParameters(
    allocator: Allocator,
    tree: *const ast.Tree,
    params_index: ast.NodeIndex,
    out: *ParamSet,
) Allocator.Error!void {
    if (params_index == .null) return;

    const params = switch (tree.data(params_index)) {
        .formal_parameters => |params| params,
        else => return,
    };

    for (tree.extra(params.items)) |item_index| {
        switch (tree.data(item_index)) {
            .formal_parameter => |parameter| try collectBinding(allocator, tree, parameter.pattern, out),
            .ts_parameter_property => |property| try collectBinding(allocator, tree, property.parameter, out),
            else => {},
        }
    }

    try collectBinding(allocator, tree, params.rest, out);
}

fn collectBinding(
    allocator: Allocator,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    out: *ParamSet,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(index)) {
        .binding_identifier => |identifier| try out.put(allocator, tree.string(identifier.name), {}),
        .assignment_pattern => |pattern| try collectBinding(allocator, tree, pattern.left, out),
        .binding_rest_element => |element| try collectBinding(allocator, tree, element.argument, out),
        .array_pattern => |pattern| {
            for (tree.extra(pattern.elements)) |element| {
                try collectBinding(allocator, tree, element, out);
            }
            try collectBinding(allocator, tree, pattern.rest, out);
        },
        .object_pattern => |pattern| {
            for (tree.extra(pattern.properties)) |property_index| {
                const property = switch (tree.data(property_index)) {
                    .binding_property => |property| property,
                    else => continue,
                };
                try collectBinding(allocator, tree, property.value, out);
            }
            try collectBinding(allocator, tree, pattern.rest, out);
        },
        else => {},
    }
}

fn scanNode(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    params: *const ParamSet,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(index)) {
        .assignment_expression => |expression| {
            try checkTarget(allocator, diagnostics, tree, params, expression.left);
            try scanNode(allocator, diagnostics, tree, params, expression.right);
        },
        .update_expression => |expression| try checkTarget(allocator, diagnostics, tree, params, expression.argument),
        .function => |function| try scanNestedFunction(allocator, diagnostics, tree, params, function),
        .arrow_function_expression => |expression| try scanNestedArrowFunction(allocator, diagnostics, tree, params, expression),
        .class,
        => return,
        inline else => |node| try scanChildren(allocator, diagnostics, tree, params, @TypeOf(node), node),
    }
}

fn scanNestedFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    params: *const ParamSet,
    function: ast.Function,
) Allocator.Error!void {
    if (function.body == .null) return;

    var filtered = try filterShadowedParams(allocator, tree, params, function.params, function.body);
    defer filtered.deinit(allocator);

    if (filtered.size == 0) return;
    try scanNode(allocator, diagnostics, tree, &filtered, function.body);
}

fn scanNestedArrowFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    params: *const ParamSet,
    expression: ast.ArrowFunctionExpression,
) Allocator.Error!void {
    var filtered = try filterShadowedParams(allocator, tree, params, expression.params, expression.body);
    defer filtered.deinit(allocator);

    if (filtered.size == 0) return;
    try scanNode(allocator, diagnostics, tree, &filtered, expression.body);
}

fn filterShadowedParams(
    allocator: Allocator,
    tree: *const ast.Tree,
    params: *const ParamSet,
    params_index: ast.NodeIndex,
    body_index: ast.NodeIndex,
) Allocator.Error!ParamSet {
    var shadows: ParamSet = .empty;
    defer shadows.deinit(allocator);

    try collectFormalParameters(allocator, tree, params_index, &shadows);
    try collectLocalDeclarations(allocator, tree, body_index, &shadows);

    var filtered: ParamSet = .empty;
    errdefer filtered.deinit(allocator);

    var iterator = params.iterator();
    while (iterator.next()) |entry| {
        const name = entry.key_ptr.*;
        if (!shadows.contains(name)) try filtered.put(allocator, name, {});
    }

    return filtered;
}

fn collectLocalDeclarations(
    allocator: Allocator,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    out: *ParamSet,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(index)) {
        .variable_declaration => |declaration| {
            for (tree.extra(declaration.declarators)) |declarator_index| {
                const declarator = switch (tree.data(declarator_index)) {
                    .variable_declarator => |declarator| declarator,
                    else => continue,
                };
                try collectBinding(allocator, tree, declarator.id, out);
            }
        },
        .function => |function| {
            try collectBinding(allocator, tree, function.id, out);
            return;
        },
        .class => |class| {
            try collectBinding(allocator, tree, class.id, out);
            return;
        },
        .arrow_function_expression => return,
        inline else => |node| try collectLocalDeclarationChildren(allocator, tree, @TypeOf(node), node, out),
    }
}

fn collectLocalDeclarationChildren(
    allocator: Allocator,
    tree: *const ast.Tree,
    comptime T: type,
    node: T,
    out: *ParamSet,
) Allocator.Error!void {
    if (@typeInfo(T) != .@"struct") return;

    inline for (@typeInfo(T).@"struct".fields) |field| {
        if (field.type == ast.NodeIndex) {
            try collectLocalDeclarations(allocator, tree, @field(node, field.name), out);
        } else if (field.type == ast.IndexRange) {
            for (tree.extra(@field(node, field.name))) |child| {
                try collectLocalDeclarations(allocator, tree, child, out);
            }
        }
    }
}

fn scanChildren(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    params: *const ParamSet,
    comptime T: type,
    node: T,
) Allocator.Error!void {
    if (@typeInfo(T) != .@"struct") return;

    inline for (@typeInfo(T).@"struct".fields) |field| {
        if (field.type == ast.NodeIndex) {
            try scanNode(allocator, diagnostics, tree, params, @field(node, field.name));
        } else if (field.type == ast.IndexRange) {
            for (tree.extra(@field(node, field.name))) |child| {
                try scanNode(allocator, diagnostics, tree, params, child);
            }
        }
    }
}

fn checkTarget(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    params: *const ParamSet,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| {
            const name = tree.string(identifier.name);
            if (!params.contains(name)) return;

            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .warning,
                id,
                tree.span(index),
                "Assignment to function parameter '{s}'.",
                .{name},
            );
        },
        .assignment_pattern => |pattern| try checkTarget(allocator, diagnostics, tree, params, pattern.left),
        .array_pattern => |pattern| {
            for (tree.extra(pattern.elements)) |element| {
                try checkTarget(allocator, diagnostics, tree, params, element);
            }
            try checkTarget(allocator, diagnostics, tree, params, pattern.rest);
        },
        .object_pattern => |pattern| {
            for (tree.extra(pattern.properties)) |property_index| {
                const property = switch (tree.data(property_index)) {
                    .binding_property => |property| property,
                    else => continue,
                };
                try checkTarget(allocator, diagnostics, tree, params, property.value);
            }
            try checkTarget(allocator, diagnostics, tree, params, pattern.rest);
        },
        .binding_rest_element => |element| try checkTarget(allocator, diagnostics, tree, params, element.argument),
        else => {},
    }
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
