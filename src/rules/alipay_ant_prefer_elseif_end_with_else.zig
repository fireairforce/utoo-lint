const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/ant/prefer-elseif-end-with-else";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.IfStatement,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (statement.alternate != .null) return;
    if (!isElseIf(tree, index, ctx)) return;
    if (allConsequentsEndWithReturn(tree, statement, ctx)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Prefer elseif end with else.",
        tree.span(index),
    );
}

fn isElseIf(tree: *const ast.Tree, index: ast.NodeIndex, ctx: *traverser.basic.Ctx) bool {
    const parent = ctx.path.parent() orelse return false;
    return switch (tree.data(parent)) {
        .if_statement => |statement| statement.alternate == index,
        else => false,
    };
}

fn allConsequentsEndWithReturn(tree: *const ast.Tree, start: ast.IfStatement, ctx: *traverser.basic.Ctx) bool {
    var current = start;
    var ancestor_depth: usize = 1;
    while (true) : (ancestor_depth += 1) {
        if (!statementEndsWithReturn(tree, current.consequent)) return false;

        const parent = ctx.path.ancestor(ancestor_depth) orelse return true;
        current = switch (tree.data(parent)) {
            .if_statement => |statement| statement,
            else => return true,
        };
    }
}

fn statementEndsWithReturn(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .return_statement => true,
        .block_statement => |block| blockEndsWithReturn(tree, block),
        else => false,
    };
}

fn blockEndsWithReturn(tree: *const ast.Tree, block: ast.BlockStatement) bool {
    const body = tree.extra(block.body);
    if (body.len == 0) return false;
    return tree.data(body[body.len - 1]) == .return_statement;
}
