const parser = @import("parser");
const core = @import("../core.zig");
const std = @import("std");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-unneeded-ternary";

pub const Options = struct {
    default_assignment: bool = true,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ConditionalExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    return checkWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ConditionalExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (isUnneededBooleanTernary(tree, expression)) {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Unnecessary use of boolean literals in conditional expression.",
            tree.span(index),
        );
        return;
    }

    if (options.default_assignment or !isDefaultAssignment(tree, expression)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unnecessary use of conditional expression for default assignment.",
        tree.span(index),
    );
}

fn isUnneededBooleanTernary(tree: *const ast.Tree, expression: ast.ConditionalExpression) bool {
    _ = booleanLiteralValue(tree, expression.consequent) orelse return false;
    _ = booleanLiteralValue(tree, expression.alternate) orelse return false;
    return true;
}

fn isDefaultAssignment(tree: *const ast.Tree, expression: ast.ConditionalExpression) bool {
    const test_name = identifierReferenceName(tree, expression.@"test") orelse return false;
    const consequent_name = identifierReferenceName(tree, expression.consequent) orelse return false;
    return std.mem.eql(u8, test_name, consequent_name);
}

fn booleanLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?bool {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .boolean_literal => |literal| literal.value,
        else => null,
    };
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
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
