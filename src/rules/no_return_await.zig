const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-return-await";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    _: ast.AwaitExpression,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (!isInTailReturnPosition(tree, ctx, 0)) return;
    if (hasErrorHandler(tree, ctx, 0)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Redundant use of await on a return value.",
        tree.span(index),
    );
}

fn isInTailReturnPosition(tree: *const ast.Tree, ctx: *traverser.basic.Ctx, depth: usize) bool {
    const current = ctx.path.ancestor(depth) orelse return false;
    const parent_index = ctx.path.ancestor(depth + 1) orelse return false;

    return switch (tree.data(parent_index)) {
        .return_statement => |statement| statement.argument == current and !hasErrorHandler(tree, ctx, depth + 1),
        .arrow_function_expression => |expression| expression.async and expression.expression and expression.body == current,
        .conditional_expression => |expression| if (expression.consequent == current or expression.alternate == current)
            isInTailReturnPosition(tree, ctx, depth + 1)
        else
            false,
        .logical_expression => |expression| expression.right == current and isInTailReturnPosition(tree, ctx, depth + 1),
        .sequence_expression => |expression| blk: {
            const expressions = tree.extra(expression.expressions);
            if (expressions.len == 0) break :blk false;
            break :blk expressions[expressions.len - 1] == current and isInTailReturnPosition(tree, ctx, depth + 1);
        },
        .parenthesized_expression => |expression| expression.expression == current and isInTailReturnPosition(tree, ctx, depth + 1),
        .chain_expression => |expression| expression.expression == current and isInTailReturnPosition(tree, ctx, depth + 1),
        else => false,
    };
}

fn hasErrorHandler(tree: *const ast.Tree, ctx: *traverser.basic.Ctx, start_depth: usize) bool {
    var depth = start_depth;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .function,
            .arrow_function_expression,
            .program,
            => return false,
            else => {},
        }

        const parent_index = ctx.path.ancestor(depth + 1) orelse return false;
        switch (tree.data(parent_index)) {
            .try_statement => |statement| {
                if (statement.block == ancestor) return true;
                if (statement.handler == ancestor and statement.finalizer != .null) return true;
            },
            else => {},
        }
    }

    return false;
}
