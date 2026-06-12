const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-fallthrough";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.SwitchStatement,
) Allocator.Error!void {
    const cases = tree.extra(statement.cases);
    if (cases.len < 2) return;

    for (cases[0 .. cases.len - 1], cases[1..]) |case_index, next_case_index| {
        const switch_case = switch (tree.data(case_index)) {
            .switch_case => |switch_case| switch_case,
            else => continue,
        };

        if (switch_case.consequent.len == 0) continue;
        if (caseAlwaysExits(tree, switch_case)) continue;
        if (hasFallthroughComment(tree, switch_case, next_case_index)) continue;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Expected a 'break' statement before this case.",
            tree.span(case_index),
        );
    }
}

fn caseAlwaysExits(tree: *const ast.Tree, switch_case: ast.SwitchCase) bool {
    const statements = tree.extra(switch_case.consequent);
    if (statements.len == 0) return false;

    return alwaysExits(tree, statements[statements.len - 1]);
}

fn alwaysExits(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .break_statement,
        .continue_statement,
        .return_statement,
        .throw_statement,
        => true,

        .block_statement => |block| rangeAlwaysExits(tree, block.body),
        .if_statement => |statement| statement.alternate != .null and
            alwaysExits(tree, statement.consequent) and
            alwaysExits(tree, statement.alternate),

        else => false,
    };
}

fn rangeAlwaysExits(tree: *const ast.Tree, range: ast.IndexRange) bool {
    const statements = tree.extra(range);
    if (statements.len == 0) return false;

    return alwaysExits(tree, statements[statements.len - 1]);
}

fn hasFallthroughComment(tree: *const ast.Tree, switch_case: ast.SwitchCase, next_case_index: ast.NodeIndex) bool {
    const statements = tree.extra(switch_case.consequent);
    if (statements.len == 0) return false;

    const last_span = tree.span(statements[statements.len - 1]);
    const next_span = tree.span(next_case_index);
    const start: u32 = last_span.end;
    const end: u32 = next_span.start;
    if (start > end) return false;

    for (tree.comments) |comment| {
        if (comment.start < start or comment.end > end) continue;
        if (isFallthroughComment(tree.string(comment.value))) return true;
    }

    return false;
}

fn isFallthroughComment(comment: []const u8) bool {
    var buffer: [256]u8 = undefined;
    const len = @min(comment.len, buffer.len);

    for (comment[0..len], 0..) |byte, index| {
        buffer[index] = std.ascii.toLower(byte);
    }

    const lower = buffer[0..len];
    return std.mem.indexOf(u8, lower, "fallthrough") != null or
        std.mem.indexOf(u8, lower, "fall through") != null or
        std.mem.indexOf(u8, lower, "falls through") != null;
}
