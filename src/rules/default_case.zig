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
    const switch_statement = switch (tree.data(index)) {
        .switch_statement => |statement| statement,
        else => return false,
    };

    const cases = tree.extra(switch_statement.cases);
    if (cases.len == 0) return false;

    const last_case_end = tree.span(cases[cases.len - 1]).end;
    const switch_end = tree.span(index).end;

    for (tree.comments) |comment| {
        if (comment.start < last_case_end or comment.end > switch_end) continue;
        const value = std.mem.trim(u8, tree.string(comment.value), &std.ascii.whitespace);
        if (std.ascii.eqlIgnoreCase(value, "no default")) return true;
    }

    return false;
}
