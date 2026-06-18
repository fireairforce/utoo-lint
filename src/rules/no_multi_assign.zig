const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-multi-assign";

pub const Options = struct {
    ignore_non_declaration: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (options.ignore_non_declaration) return;
    if (!isAssignmentExpression(tree, expression.right)) return;

    try addDiagnostic(
        allocator,
        diagnostics,
        tree.span(index),
    );
}

pub fn checkVariableDeclarator(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
) Allocator.Error!void {
    if (!isAssignmentExpression(tree, declarator.init)) return;

    try addDiagnostic(
        allocator,
        diagnostics,
        tree.span(declarator.init),
    );
}

pub fn checkPropertyDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.PropertyDefinition,
) Allocator.Error!void {
    if (!isAssignmentExpression(tree, property.value)) return;

    try addDiagnostic(
        allocator,
        diagnostics,
        tree.span(property.value),
    );
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    span: ast.Span,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected chained assignment.",
        span,
    );
}

fn isAssignmentExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .assignment_expression => true,
        else => false,
    };
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
