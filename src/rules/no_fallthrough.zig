const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-fallthrough";

pub const Options = struct {
    allow_empty_case: bool = false,
    report_unused_fallthrough_comment: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.SwitchStatement,
) Allocator.Error!void {
    try checkWithOptions(allocator, diagnostics, tree, statement, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.SwitchStatement,
    options: Options,
) Allocator.Error!void {
    const cases = tree.extra(statement.cases);
    if (cases.len < 2) return;

    for (cases[0 .. cases.len - 1], cases[1..]) |case_index, next_case_index| {
        const switch_case = switch (tree.data(case_index)) {
            .switch_case => |switch_case| switch_case,
            else => continue,
        };

        if (switch_case.consequent.len == 0) {
            if (allowsEmptyCase(tree, case_index, next_case_index, options)) continue;
        } else {
            if (caseAlwaysExits(tree, switch_case)) {
                if (options.report_unused_fallthrough_comment and hasFallthroughComment(tree, switch_case, next_case_index)) {
                    try addUnusedFallthroughCommentDiagnostic(allocator, diagnostics, tree, case_index);
                }
                continue;
            }
            if (hasFallthroughComment(tree, switch_case, next_case_index)) continue;
        }

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

fn addUnusedFallthroughCommentDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Found a fallthrough comment, but this case cannot fall through.",
        tree.span(index),
    );
}

fn allowsEmptyCase(tree: *const ast.Tree, case_index: ast.NodeIndex, next_case_index: ast.NodeIndex, options: Options) bool {
    if (options.allow_empty_case) return true;
    if (caseLabelsAreAdjacent(tree, case_index, next_case_index)) return true;
    return hasFallthroughCommentBetween(tree, tree.span(case_index).end, tree.span(next_case_index).start);
}

fn caseLabelsAreAdjacent(tree: *const ast.Tree, case_index: ast.NodeIndex, next_case_index: ast.NodeIndex) bool {
    const current = offsetToLine(tree.source, tree.span(case_index).end);
    const next = offsetToLine(tree.source, tree.span(next_case_index).start);
    return next <= current + 1;
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
        .try_statement => |statement| alwaysExits(tree, statement.block) or
            alwaysExits(tree, statement.finalizer),

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

    return hasFallthroughCommentBetween(tree, start, end);
}

fn hasFallthroughCommentBetween(tree: *const ast.Tree, start: u32, end: u32) bool {
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

fn offsetToLine(source: []const u8, offset: u32) usize {
    const limit = @min(@as(usize, @intCast(offset)), source.len);
    var line: usize = 1;

    for (source[0..limit]) |byte| {
        if (byte == '\n') line += 1;
    }

    return line;
}
