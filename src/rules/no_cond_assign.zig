const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-cond-assign";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NodeIndex,
) Allocator.Error!void {
    if (findAmbiguousAssignment(tree, expression)) |assignment| {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Expected a conditional expression and instead saw an assignment.",
            tree.span(assignment),
        );
    }
}

fn findAmbiguousAssignment(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.NodeIndex {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .parenthesized_expression => null,
        .assignment_expression => index,
        .chain_expression => |chain| return findAmbiguousAssignment(tree, chain.expression),
        else => null,
    };
}
