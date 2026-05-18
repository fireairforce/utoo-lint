const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-console";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isConsoleMemberCall(tree, call.callee)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected console call.",
        tree.span(index),
    );
}

fn isConsoleMemberCall(tree: *const ast.Tree, callee: ast.NodeIndex) bool {
    var current = callee;

    switch (tree.data(current)) {
        .chain_expression => |chain| current = chain.expression,
        else => {},
    }

    return switch (tree.data(current)) {
        .member_expression => |member| isIdentifierNamed(tree, member.object, "console"),
        else => false,
    };
}

fn isIdentifierNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
    };
}

