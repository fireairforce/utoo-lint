const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-new-require";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NewExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isRequireConstructorCallee(tree, expression.callee)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Do not use new with require().",
        tree.span(index),
    );
}

fn isRequireConstructorCallee(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const unwrapped = unwrapTransparent(tree, index);
    switch (tree.data(unwrapped)) {
        .identifier_reference => |identifier| return std.mem.eql(u8, tree.string(identifier.name), "require"),
        .call_expression => |call| {
            const callee = unwrapTransparent(tree, call.callee);
            return switch (tree.data(callee)) {
                .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), "require"),
                else => false,
            };
        },
        else => return false,
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
