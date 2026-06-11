const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

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

fn isStatementBody(tree: *const ast.Tree, index: ast.NodeIndex, ctx: *traverser.basic.Ctx) bool {
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
