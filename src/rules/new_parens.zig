const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "new-parens";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NewExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (expression.arguments.len != 0) return;
    if (hasTrailingParen(tree, index)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Missing '()' invoking a constructor.",
        tree.span(index),
    );
}

fn hasTrailingParen(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (start >= end or end > tree.source.len) return false;

    var offset = end;
    while (offset > start) {
        offset -= 1;
        switch (tree.source[offset]) {
            ' ', '\t', '\n', '\r', 0x0B, 0x0C => {},
            ')' => return true,
            else => return false,
        }
    }

    return false;
}
