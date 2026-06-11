const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-lonely-if";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.IfStatement,
) Allocator.Error!void {
    const lonely_if = lonelyIf(tree, statement) orelse return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected if as the only statement in an else block.",
        tree.span(lonely_if),
    );
}

fn lonelyIf(tree: *const ast.Tree, statement: ast.IfStatement) ?ast.NodeIndex {
    if (statement.alternate == .null) return null;

    const block = switch (tree.data(statement.alternate)) {
        .block_statement => |block| block,
        else => return null,
    };
    if (block.body.len != 1) return null;

    const child = tree.extra(block.body)[0];
    return switch (tree.data(child)) {
        .if_statement => child,
        else => null,
    };
}
