const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "func-names";

pub const Style = enum {
    always,
    as_needed,
    never,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    return checkWithStyle(allocator, diagnostics, tree, function, index, ctx, .always);
}

pub fn checkWithStyle(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    style: Style,
) Allocator.Error!void {
    if (style == .never) {
        if (!disallowsName(tree, function, ctx)) return;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Unexpected named function.",
            tree.span(index),
        );
        return;
    }

    if (function.id != .null) return;
    if (!requiresName(tree, function, index, ctx, style)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected unnamed function.",
        tree.span(index),
    );
}

fn requiresName(tree: *const ast.Tree, function: ast.Function, index: ast.NodeIndex, ctx: *traverser.basic.Ctx, style: Style) bool {
    return switch (function.type) {
        .function_expression => !isMethodParent(tree, ctx) and !allowsInferredName(tree, index, ctx, style),
        .function_declaration => isExportDefaultDeclarationParent(tree, ctx),
        else => false,
    };
}

fn disallowsName(tree: *const ast.Tree, function: ast.Function, ctx: *traverser.basic.Ctx) bool {
    return switch (function.type) {
        .function_expression => function.id != .null and !isMethodParent(tree, ctx),
        else => false,
    };
}

fn allowsInferredName(tree: *const ast.Tree, index: ast.NodeIndex, ctx: *traverser.basic.Ctx, style: Style) bool {
    if (style != .as_needed) return false;

    const parent = ctx.path.parent() orelse return false;
    return switch (tree.data(parent)) {
        .variable_declarator => |declarator| declarator.init == index,
        .object_property => |property| property.value == index,
        .property_definition => |property| property.value == index,
        .assignment_pattern => |pattern| pattern.right == index,
        .assignment_expression => |assignment| assignment.right == index and isInferredAssignment(tree, assignment),
        else => false,
    };
}

fn isInferredAssignment(tree: *const ast.Tree, assignment: ast.AssignmentExpression) bool {
    if (!isNameInferringAssignmentOperator(assignment.operator)) return false;

    return switch (tree.data(assignment.left)) {
        .identifier_reference => true,
        else => false,
    };
}

fn isNameInferringAssignmentOperator(operator: ast.AssignmentOperator) bool {
    return switch (operator) {
        .assign,
        .logical_or_assign,
        .logical_and_assign,
        .nullish_assign,
        => true,
        else => false,
    };
}

fn isMethodParent(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    const parent = ctx.path.parent() orelse return false;
    return switch (tree.data(parent)) {
        .method_definition => true,
        .object_property => |property| property.method,
        else => false,
    };
}

fn isExportDefaultDeclarationParent(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    const parent = ctx.path.parent() orelse return false;
    return switch (tree.data(parent)) {
        .export_default_declaration => true,
        else => false,
    };
}
