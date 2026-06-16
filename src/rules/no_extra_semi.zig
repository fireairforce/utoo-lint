const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-extra-semi";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (isStatementBody(tree, index, ctx)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unnecessary semicolon.",
        tree.span(index),
    );
}

pub fn checkClassBody(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.ClassBody,
    index: ast.NodeIndex,
) Allocator.Error!void {
    var current: usize = @intCast(tree.span(index).start + 1);

    for (tree.extra(body.body)) |member_index| {
        const member_span = tree.span(member_index);
        try reportSemicolonsInRange(allocator, diagnostics, tree, current, @intCast(member_span.start));
        current = @intCast(member_span.end);
    }

    const body_span = tree.span(index);
    if (body_span.end == 0) return;
    try reportSemicolonsInRange(allocator, diagnostics, tree, current, @intCast(body_span.end - 1));
}

fn reportSemicolonsInRange(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    start: usize,
    end: usize,
) Allocator.Error!void {
    if (start >= end or end > tree.source.len) return;

    for (tree.source[start..end], start..) |byte, offset| {
        if (byte != ';') continue;
        const semicolon: u32 = @intCast(offset);
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Unnecessary semicolon.",
            .{ .start = semicolon, .end = semicolon + 1 },
        );
    }
}

pub fn isStatementBody(tree: *const ast.Tree, index: ast.NodeIndex, ctx: *traverser.basic.Ctx) bool {
    const parent = ctx.path.ancestor(1) orelse return false;

    return switch (tree.data(parent)) {
        .if_statement => |statement| statement.consequent == index or statement.alternate == index,
        .for_statement => |statement| statement.body == index,
        .for_in_statement => |statement| statement.body == index,
        .for_of_statement => |statement| statement.body == index,
        .while_statement => |statement| statement.body == index,
        .do_while_statement => |statement| statement.body == index,
        .with_statement => |statement| statement.body == index,
        .labeled_statement => |statement| statement.body == index,
        else => false,
    };
}
