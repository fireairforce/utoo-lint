const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "arrow-body-style";

pub const Style = enum {
    always,
    as_needed,
    never,
};

pub const Options = struct {
    style: Style = .as_needed,
    require_return_for_object_literal: bool = false,
};

pub fn checkArrowFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ArrowFunctionExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (options.style == .always) {
        if (expression.expression) {
            try core.addDiagnostic(
                allocator,
                diagnostics,
                .warning,
                id,
                "Expected block statement surrounding arrow body.",
                tree.span(index),
            );
        }
        return;
    }

    if (expression.expression) return;
    const returned = singleReturnedExpression(tree, expression.body) orelse return;
    if (options.style == .as_needed and options.require_return_for_object_literal and isObjectExpression(tree, returned)) {
        return;
    }

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected block statement surrounding arrow body; move the returned value immediately after the `=>`.",
        tree.span(expression.body),
    );
}

fn singleReturnedExpression(tree: *const ast.Tree, body_index: ast.NodeIndex) ?ast.NodeIndex {
    const body = switch (tree.data(body_index)) {
        .function_body => |body| body,
        else => return null,
    };

    const statements = tree.extra(body.body);
    if (statements.len != 1) return null;

    const statement = switch (tree.data(statements[0])) {
        .return_statement => |statement| statement,
        else => return null,
    };
    if (statement.argument == .null) return null;
    return statement.argument;
}

fn isObjectExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .object_expression => true,
        else => false,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;
    while (current != .null) {
        switch (tree.data(current)) {
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            else => return current,
        }
    }
    return current;
}
