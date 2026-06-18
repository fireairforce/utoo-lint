const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "default-case";

pub const Options = struct {
    comment_pattern: core.DefaultCaseCommentPattern = .{},
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.SwitchStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    return checkWithOptions(allocator, diagnostics, tree, statement, index, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.SwitchStatement,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (hasDefaultCase(tree, statement)) return;
    if (hasNoDefaultComment(tree, index, options)) return;

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

fn hasNoDefaultComment(tree: *const ast.Tree, index: ast.NodeIndex, options: Options) bool {
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
        if (commentMatchesPattern(value, options.comment_pattern)) return true;
    }

    return false;
}

fn commentMatchesPattern(value: []const u8, pattern: core.DefaultCaseCommentPattern) bool {
    const custom_pattern = pattern.pattern() orelse return std.ascii.eqlIgnoreCase(value, "no default");
    return matchesPattern(value, custom_pattern);
}

fn matchesPattern(value: []const u8, pattern: []const u8) bool {
    var start: usize = 0;
    while (start <= pattern.len) {
        const remainder = pattern[start..];
        const separator = std.mem.indexOfScalar(u8, remainder, '|');
        const end = if (separator) |offset| start + offset else pattern.len;
        if (matchesAlternative(value, pattern[start..end])) return true;
        if (separator == null) break;
        start = end + 1;
    }
    return false;
}

fn matchesAlternative(value: []const u8, pattern: []const u8) bool {
    const anchored_start = std.mem.startsWith(u8, pattern, "^");
    const anchored_end = std.mem.endsWith(u8, pattern, "$");
    const body_start: usize = if (anchored_start) 1 else 0;
    const body_end = if (anchored_end and pattern.len > body_start) pattern.len - 1 else pattern.len;
    const body = pattern[body_start..body_end];

    if (std.mem.indexOf(u8, body, ".*") != null) {
        return matchesWildcardSequence(value, body, anchored_start, anchored_end);
    }
    if (anchored_start and anchored_end) return std.mem.eql(u8, value, body);
    if (anchored_start) return std.mem.startsWith(u8, value, body);
    if (anchored_end) return std.mem.endsWith(u8, value, body);
    return std.mem.indexOf(u8, value, body) != null;
}

fn matchesWildcardSequence(value: []const u8, pattern: []const u8, anchored_start: bool, anchored_end: bool) bool {
    var value_offset: usize = 0;
    var pattern_offset: usize = 0;
    var part_index: usize = 0;

    while (pattern_offset <= pattern.len) : (part_index += 1) {
        const remainder = pattern[pattern_offset..];
        const wildcard = std.mem.indexOf(u8, remainder, ".*");
        const part_end = if (wildcard) |offset| pattern_offset + offset else pattern.len;
        const part = pattern[pattern_offset..part_end];

        if (part.len > 0) {
            if (part_index == 0 and anchored_start) {
                if (!std.mem.startsWith(u8, value[value_offset..], part)) return false;
                value_offset += part.len;
            } else {
                const found = std.mem.indexOf(u8, value[value_offset..], part) orelse return false;
                value_offset += found + part.len;
            }
        }

        if (wildcard == null) break;
        pattern_offset = part_end + 2;
    }

    if (!anchored_end) return true;
    const suffix_start = lastWildcardPartStart(pattern);
    return std.mem.endsWith(u8, value, pattern[suffix_start..]);
}

fn lastWildcardPartStart(pattern: []const u8) usize {
    var offset: usize = 0;
    var start: usize = 0;
    while (offset < pattern.len) {
        const wildcard = std.mem.indexOf(u8, pattern[offset..], ".*") orelse break;
        start = offset + wildcard + 2;
        offset = start;
    }
    return start;
}
