const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/consistent-type-assertions";

pub fn checkAsExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.TSAsExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (isConstType(tree, expression.type_annotation)) return;
    if (!isObjectExpression(tree, expression.expression)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Always prefer const x: T = { ... }.",
        tree.span(index),
    );
}

pub fn checkTypeAssertion(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    assertion: ast.TSTypeAssertion,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const type_text = sourceText(tree, assertion.type_annotation);

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "Use 'as {s}' instead of '<{s}>'.",
        .{ type_text, type_text },
    );
}

fn isObjectExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .object_expression => true,
        else => false,
    };
}

fn isConstType(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .ts_type_reference => |reference| blk: {
            const name = typeName(tree, reference.type_name) orelse break :blk false;
            break :blk std.mem.eql(u8, name, "const");
        },
        else => false,
    };
}

fn typeName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;
    while (current != .null) {
        switch (tree.data(current)) {
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            .chain_expression => |chain| current = chain.expression,
            else => return current,
        }
    }
    return current;
}

fn sourceText(tree: *const ast.Tree, index: ast.NodeIndex) []const u8 {
    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (start > end or end > tree.source.len) return "T";
    return tree.source[start..end];
}
