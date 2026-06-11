const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-await-in-loop";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (!isInsideLoop(tree, ctx)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected await inside a loop.",
        tree.span(index),
    );
}

fn isInsideLoop(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .arrow_function_expression,
            .function,
            => return false,
            .for_statement,
            .for_in_statement,
            .for_of_statement,
            .while_statement,
            .do_while_statement,
            => return true,
            else => {},
        }
    }

    return false;
}
