const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-console";

pub const Options = struct {
    allow: core.NoConsoleAllow = .{},
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkWithOptions(allocator, diagnostics, tree, call, index, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    const member = consoleMemberCall(tree, call.callee) orelse return;
    const method = propertyName(tree, member);
    if (method != null and options.allow.contains(method.?)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected console call.",
        tree.span(index),
    );
}

fn consoleMemberCall(tree: *const ast.Tree, callee: ast.NodeIndex) ?ast.MemberExpression {
    var current = callee;

    switch (tree.data(current)) {
        .chain_expression => |chain| current = chain.expression,
        else => {},
    }

    return switch (tree.data(current)) {
        .member_expression => |member| if (isIdentifierNamed(tree, member.object, "console")) member else null,
        else => null,
    };
}

fn propertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;

    return if (member.computed)
        switch (tree.data(member.property)) {
            .string_literal => |literal| tree.string(literal.value),
            else => null,
        }
    else switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isIdentifierNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
    };
}
