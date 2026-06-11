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
    statement: ast.ReturnStatement,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (!isAwaitExpression(tree, statement.argument)) return;
    if (!isInsideAsyncFunction(tree, ctx)) return;
    if (isInsideTryBlock(tree, ctx)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Redundant use of await on a return value.",
        tree.span(index),
    );
}

fn isAwaitExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .await_expression => true,
        else => false,
    };
}

fn isInsideAsyncFunction(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .arrow_function_expression => |function| return function.async,
            .function => |function| return function.async,
            else => {},
        }
    }

    return false;
}

fn isInsideTryBlock(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .arrow_function_expression,
            .function,
            => return false,
            .try_statement => |statement| {
                const child = ctx.path.ancestor(depth - 1) orelse return false;
                return statement.block == child;
            },
            else => {},
        }
    }

    return false;
}
