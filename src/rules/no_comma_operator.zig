const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-comma-operator";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    _: ast.SequenceExpression,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (isNestedSequence(tree, ctx)) return;
    if (isAllowedForPart(tree, index, ctx)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "The comma operator is disallowed.",
        tree.span(index),
    );
}

fn isNestedSequence(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    const parent = ctx.path.ancestor(1) orelse return false;
    return switch (tree.data(parent)) {
        .sequence_expression => true,
        else => false,
    };
}

fn isAllowedForPart(
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) bool {
    const parent = ctx.path.ancestor(1) orelse return false;
    const for_statement = switch (tree.data(parent)) {
        .for_statement => |for_statement| for_statement,
        else => return false,
    };

    return for_statement.init == index or for_statement.update == index;
}
