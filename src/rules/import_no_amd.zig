const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "import/no-amd";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const callee_name = calleeName(tree, call.callee) orelse return;
    if (!std.mem.eql(u8, callee_name, "define") and !std.mem.eql(u8, callee_name, "require")) return;
    if (!hasDependencyArray(tree, call.arguments)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Expected imports instead of AMD {s}().",
        .{callee_name},
    );
}

fn calleeName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn hasDependencyArray(tree: *const ast.Tree, arguments: ast.IndexRange) bool {
    const items = tree.extra(arguments);
    if (items.len == 0) return false;
    return tree.data(items[0]) == .array_expression;
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
