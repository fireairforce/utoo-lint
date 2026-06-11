const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-constructor-return";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ReturnStatement,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (statement.argument == .null) return;
    if (!isInsideConstructorBody(tree, ctx)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected return of a value in constructor.",
        tree.span(index),
    );
}

fn isInsideConstructorBody(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .arrow_function_expression => return false,
            .function => {
                const parent = ctx.path.ancestor(depth + 1) orelse return false;
                return switch (tree.data(parent)) {
                    .method_definition => |method| method.kind == .constructor and method.value == ancestor,
                    else => false,
                };
            },
            else => {},
        }
    }

    return false;
}
