const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-unnecessary-parameter-property-assignment";

pub fn checkClass(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    class: ast.Class,
) Allocator.Error!void {
    const body = switch (tree.data(class.body)) {
        .class_body => |body| body,
        else => return,
    };

    for (tree.extra(body.body)) |member_index| {
        const method = switch (tree.data(member_index)) {
            .method_definition => |method| method,
            else => continue,
        };
        if (method.kind != .constructor) continue;

        const function = switch (tree.data(method.value)) {
            .function => |function| function,
            else => continue,
        };
        try checkConstructor(allocator, diagnostics, tree, function);
    }
}

fn checkConstructor(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
) Allocator.Error!void {
    const params = switch (tree.data(function.params)) {
        .formal_parameters => |params| params,
        else => return,
    };

    var parameter_properties: std.ArrayList([]const u8) = .empty;
    defer parameter_properties.deinit(allocator);

    for (tree.extra(params.items)) |param_index| {
        const parameter_property = switch (tree.data(param_index)) {
            .ts_parameter_property => |parameter_property| parameter_property,
            else => continue,
        };
        const name = parameterPropertyName(tree, parameter_property) orelse continue;
        try parameter_properties.append(allocator, name);
    }

    if (parameter_properties.items.len == 0 or function.body == .null) return;

    const body = switch (tree.data(function.body)) {
        .function_body => |body| body,
        else => return,
    };

    for (tree.extra(body.body)) |statement_index| {
        try checkStatement(allocator, diagnostics, tree, statement_index, parameter_properties.items);
    }
}

fn checkStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement_index: ast.NodeIndex,
    parameter_properties: []const []const u8,
) Allocator.Error!void {
    switch (tree.data(statement_index)) {
        .expression_statement => |statement| try checkExpression(allocator, diagnostics, tree, statement.expression, parameter_properties),
        .block_statement => |block| {
            for (tree.extra(block.body)) |child_statement| {
                try checkStatement(allocator, diagnostics, tree, child_statement, parameter_properties);
            }
        },
        .if_statement => |statement| {
            try checkStatement(allocator, diagnostics, tree, statement.consequent, parameter_properties);
            if (statement.alternate != .null) {
                try checkStatement(allocator, diagnostics, tree, statement.alternate, parameter_properties);
            }
        },
        else => {},
    }
}

fn checkExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression_index: ast.NodeIndex,
    parameter_properties: []const []const u8,
) Allocator.Error!void {
    const expression = switch (tree.data(expression_index)) {
        .assignment_expression => |expression| expression,
        else => return,
    };
    if (expression.operator != .assign) return;

    const assignment = unnecessaryAssignment(tree, expression, parameter_properties) orelse return;
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(expression_index),
        "Assignment to parameter property `{s}` is unnecessary.",
        .{assignment},
    );
}

fn unnecessaryAssignment(
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    parameter_properties: []const []const u8,
) ?[]const u8 {
    const left_name = thisPropertyName(tree, expression.left) orelse return null;
    const right_name = identifierName(tree, expression.right) orelse return null;
    if (!std.mem.eql(u8, left_name, right_name)) return null;

    for (parameter_properties) |parameter_property| {
        if (std.mem.eql(u8, parameter_property, left_name)) return parameter_property;
    }
    return null;
}

fn parameterPropertyName(tree: *const ast.Tree, property: ast.TSParameterProperty) ?[]const u8 {
    return switch (tree.data(property.parameter)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        .assignment_pattern => |pattern| switch (tree.data(pattern.left)) {
            .binding_identifier => |identifier| tree.string(identifier.name),
            else => null,
        },
        else => null,
    };
}

fn thisPropertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    const member = switch (tree.data(index)) {
        .member_expression => |member| member,
        else => return null,
    };
    if (member.computed) return null;
    if (tree.data(member.object) != .this_expression) return null;

    return switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn identifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}
