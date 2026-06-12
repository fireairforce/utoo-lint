const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-useless-return";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ReturnStatement,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (statement.argument != .null) return;
    if (!isRedundantReturn(tree, index, ctx)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unnecessary return statement.",
        tree.span(index),
    );
}

fn isRedundantReturn(tree: *const ast.Tree, index: ast.NodeIndex, ctx: *traverser.basic.Ctx) bool {
    var child = index;
    var depth: usize = 1;

    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .function_body => |body| return isLastInRange(tree, child, body.body),
            .block_statement => |block| {
                if (!isLastInRange(tree, child, block.body)) return false;
                child = ancestor;
            },
            .switch_case => |case| {
                if (!isLastInRange(tree, child, case.consequent)) return false;
                child = ancestor;
            },
            .switch_statement => |statement| {
                if (!isLastInRange(tree, child, statement.cases)) return false;
                child = ancestor;
            },
            .if_statement => |statement| {
                if (statement.consequent != child and statement.alternate != child) return false;
                child = ancestor;
            },
            .while_statement,
            .do_while_statement,
            .for_statement,
            .for_in_statement,
            .for_of_statement,
            .try_statement,
            .catch_clause,
            => return false,
            .function,
            .arrow_function_expression,
            .program,
            => return false,
            else => child = ancestor,
        }
    }

    return false;
}

fn isLastInRange(tree: *const ast.Tree, index: ast.NodeIndex, range: ast.IndexRange) bool {
    if (range.len == 0) return false;
    const items = tree.extra(range);
    return items[items.len - 1] == index;
}
