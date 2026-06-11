const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "default-case";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.SwitchStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (hasDefaultCase(tree, statement)) return;
    if (hasNoDefaultComment(tree, index)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Expected a default case.",
        tree.span(index),
    );
}

fn hasDefaultCase(tree: *const ast.Tree, statement: ast.SwitchStatement) bool {
    for (tree.extra(statement.cases)) |case_index| {
        const switch_case = switch (tree.data(case_index)) {
            .switch_case => |switch_case| switch_case,
            else => continue,
        };
        if (switch_case.@"test" == .null) return true;
    }

    return false;
}

fn hasNoDefaultComment(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (start >= end or end > tree.source.len) return false;

    return std.mem.indexOf(u8, tree.source[start..end], "no default") != null;
}
