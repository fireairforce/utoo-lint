const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "func-style";

pub const Style = enum {
    expression,
    declaration,
};

pub const NamedExports = enum {
    unset,
    expression,
    declaration,
    ignore,
};

pub const Options = struct {
    style: Style = .expression,
    allow_arrow_functions: bool = false,
    allow_type_annotation: bool = false,
    named_exports: NamedExports = .unset,
};

pub fn checkFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (function.type != .function_declaration) return;

    const parent = ctx.path.ancestor(1);
    if (isExportDefault(tree, parent)) return;

    if (isExportNamed(tree, parent)) {
        switch (options.named_exports) {
            .expression => try addDiagnostic(allocator, diagnostics, tree, index, .expression),
            .declaration, .ignore => {},
            .unset => if (options.style == .expression) try addDiagnostic(allocator, diagnostics, tree, index, .expression),
        }
        return;
    }

    if (options.style == .expression) {
        try addDiagnostic(allocator, diagnostics, tree, index, .expression);
    }
}

pub fn checkVariableDeclarator(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    const init = unwrapTransparent(tree, declarator.init);
    const init_kind = functionInitKind(tree, init) orelse return;
    if (init_kind == .arrow and (options.allow_arrow_functions or nodeUsesThisOrSuper(tree, init))) return;
    if (options.allow_type_annotation and hasTypeAnnotation(tree, declarator.id)) return;

    const export_named = isVariableDeclaratorExportNamed(tree, ctx);
    if (export_named) {
        switch (options.named_exports) {
            .declaration => try addDiagnostic(allocator, diagnostics, tree, index, .declaration),
            .expression, .ignore => {},
            .unset => if (options.style == .declaration) try addDiagnostic(allocator, diagnostics, tree, index, .declaration),
        }
        return;
    }

    if (options.style == .declaration) {
        try addDiagnostic(allocator, diagnostics, tree, index, .declaration);
    }
}

const InitKind = enum {
    function,
    arrow,
};

fn functionInitKind(tree: *const ast.Tree, index: ast.NodeIndex) ?InitKind {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .function => |function| if (function.type == .function_expression) .function else null,
        .arrow_function_expression => .arrow,
        else => null,
    };
}

fn isExportDefault(tree: *const ast.Tree, parent: ?ast.NodeIndex) bool {
    const index = parent orelse return false;
    return tree.data(index) == .export_default_declaration;
}

fn isExportNamed(tree: *const ast.Tree, parent: ?ast.NodeIndex) bool {
    const index = parent orelse return false;
    return tree.data(index) == .export_named_declaration;
}

fn isVariableDeclaratorExportNamed(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    const declaration_index = ctx.path.ancestor(1) orelse return false;
    const parent_index = ctx.path.ancestor(2) orelse return false;
    return tree.data(declaration_index) == .variable_declaration and
        tree.data(parent_index) == .export_named_declaration;
}

fn hasTypeAnnotation(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| identifier.type_annotation != .null,
        .assignment_pattern => |pattern| hasTypeAnnotation(tree, pattern.left),
        .binding_rest_element => |element| hasTypeAnnotation(tree, element.argument),
        else => false,
    };
}

fn nodeUsesThisOrSuper(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .this_expression, .super => true,
        .function, .class => false,
        .arrow_function_expression => |arrow| nodeUsesThisOrSuper(tree, arrow.body),
        .function_body => |body| rangeUsesThisOrSuper(tree, body.body),
        .expression_statement => |statement| nodeUsesThisOrSuper(tree, statement.expression),
        .return_statement => |statement| nodeUsesThisOrSuper(tree, statement.argument),
        .block_statement => |block| rangeUsesThisOrSuper(tree, block.body),
        .parenthesized_expression => |expression| nodeUsesThisOrSuper(tree, expression.expression),
        .chain_expression => |expression| nodeUsesThisOrSuper(tree, expression.expression),
        .member_expression => |expression| nodeUsesThisOrSuper(tree, expression.object) or
            nodeUsesThisOrSuper(tree, expression.property),
        .call_expression => |expression| nodeUsesThisOrSuper(tree, expression.callee) or
            rangeUsesThisOrSuper(tree, expression.arguments),
        .assignment_expression => |expression| nodeUsesThisOrSuper(tree, expression.left) or
            nodeUsesThisOrSuper(tree, expression.right),
        .binary_expression => |expression| nodeUsesThisOrSuper(tree, expression.left) or
            nodeUsesThisOrSuper(tree, expression.right),
        .logical_expression => |expression| nodeUsesThisOrSuper(tree, expression.left) or
            nodeUsesThisOrSuper(tree, expression.right),
        .conditional_expression => |expression| nodeUsesThisOrSuper(tree, expression.@"test") or
            nodeUsesThisOrSuper(tree, expression.consequent) or
            nodeUsesThisOrSuper(tree, expression.alternate),
        .unary_expression => |expression| nodeUsesThisOrSuper(tree, expression.argument),
        .update_expression => |expression| nodeUsesThisOrSuper(tree, expression.argument),
        .await_expression => |expression| nodeUsesThisOrSuper(tree, expression.argument),
        .yield_expression => |expression| nodeUsesThisOrSuper(tree, expression.argument),
        .sequence_expression => |expression| rangeUsesThisOrSuper(tree, expression.expressions),
        .array_expression => |expression| rangeUsesThisOrSuper(tree, expression.elements),
        .object_expression => |expression| rangeUsesThisOrSuper(tree, expression.properties),
        .object_property => |property| nodeUsesThisOrSuper(tree, property.key) or
            nodeUsesThisOrSuper(tree, property.value),
        .spread_element => |element| nodeUsesThisOrSuper(tree, element.argument),
        else => false,
    };
}

fn rangeUsesThisOrSuper(tree: *const ast.Tree, range: ast.IndexRange) bool {
    for (tree.extra(range)) |child| {
        if (nodeUsesThisOrSuper(tree, child)) return true;
    }
    return false;
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

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    expected: Style,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        switch (expected) {
            .expression => "Expected a function expression.",
            .declaration => "Expected a function declaration.",
        },
        tree.span(index),
    );
}
