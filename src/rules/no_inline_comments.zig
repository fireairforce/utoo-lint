const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-inline-comments";

pub const Options = struct {
    ignore_pattern: core.NoInlineCommentsIgnorePattern = .{},
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    try runWithOptions(allocator, diagnostics, tree, .{});
}

pub fn runWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    options: Options,
) Allocator.Error!void {
    const source = tree.source;

    for (tree.comments) |comment| {
        const start: usize = comment.start;
        const end: usize = comment.end;
        const line_start = findLineStart(source, start);
        const line_end = findLineEnd(source, start);

        const has_code_before = hasNonWhitespace(source[line_start..start]);
        const has_code_after = comment.type == .block and end <= line_end and hasNonWhitespace(source[end..line_end]);

        if (has_code_before or has_code_after) {
            if (isIgnoredComment(source[start..end], options.ignore_pattern)) continue;

            try core.addDiagnostic(
                allocator,
                diagnostics,
                .warning,
                id,
                "Unexpected comment inline with code.",
                .{ .start = @intCast(start), .end = @intCast(end) },
            );
        }
    }
}

fn findLineStart(source: []const u8, start: usize) usize {
    var index = start;
    while (index > 0) {
        const previous = index - 1;
        if (source[previous] == '\n' or source[previous] == '\r') break;
        index = previous;
    }
    return index;
}

fn findLineEnd(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and source[index] != '\n' and source[index] != '\r') : (index += 1) {}
    return index;
}

fn hasNonWhitespace(source: []const u8) bool {
    for (source) |char| {
        if (char != ' ' and char != '\t' and char != 0x0B and char != 0x0C) return true;
    }
    return false;
}

fn isIgnoredComment(comment_text: []const u8, pattern: core.NoInlineCommentsIgnorePattern) bool {
    const custom_pattern = pattern.pattern() orelse return false;
    return matchesPattern(comment_text, custom_pattern);
}

fn matchesPattern(value: []const u8, pattern: []const u8) bool {
    var start: usize = 0;
    while (start <= pattern.len) {
        const separator = indexOfUnescapedPipe(pattern[start..]);
        const end = if (separator) |offset| start + offset else pattern.len;
        if (matchesAlternative(value, pattern[start..end])) return true;
        if (separator == null) break;
        start = end + 1;
    }
    return false;
}

fn indexOfUnescapedPipe(pattern: []const u8) ?usize {
    var index: usize = 0;
    var escaped = false;
    while (index < pattern.len) : (index += 1) {
        if (escaped) {
            escaped = false;
            continue;
        }
        if (pattern[index] == '\\') {
            escaped = true;
            continue;
        }
        if (pattern[index] == '|') return index;
    }
    return null;
}

fn matchesAlternative(value: []const u8, pattern: []const u8) bool {
    if (pattern.len == 0) return false;

    const anchored_start = std.mem.startsWith(u8, pattern, "^");
    const anchored_end = std.mem.endsWith(u8, pattern, "$") and !isEscaped(pattern, pattern.len - 1);
    const body_start: usize = if (anchored_start) 1 else 0;
    const body_end = if (anchored_end and pattern.len > body_start) pattern.len - 1 else pattern.len;
    const body = pattern[body_start..body_end];

    if (anchored_start) return matchAt(value, body, 0, 0, anchored_end);

    var start: usize = 0;
    while (start <= value.len) : (start += 1) {
        if (matchAt(value, body, start, 0, anchored_end)) return true;
    }
    return false;
}

fn isEscaped(pattern: []const u8, index: usize) bool {
    if (index == 0) return false;
    var backslashes: usize = 0;
    var cursor = index;
    while (cursor > 0 and pattern[cursor - 1] == '\\') : (cursor -= 1) {
        backslashes += 1;
    }
    return backslashes % 2 == 1;
}

fn matchAt(value: []const u8, pattern: []const u8, value_index: usize, pattern_index: usize, anchored_end: bool) bool {
    if (pattern_index >= pattern.len) return !anchored_end or value_index == value.len;
    if (value_index > value.len) return false;

    const token = readToken(pattern, pattern_index);
    const quantifier_index = pattern_index + token.pattern_len;
    const quantifier = if (quantifier_index < pattern.len and (pattern[quantifier_index] == '*' or pattern[quantifier_index] == '+')) pattern[quantifier_index] else 0;
    const next_pattern_index = quantifier_index + if (quantifier == 0) @as(usize, 0) else @as(usize, 1);

    if (quantifier == 0) {
        if (value_index >= value.len or !tokenMatches(token, value[value_index])) return false;
        return matchAt(value, pattern, value_index + 1, next_pattern_index, anchored_end);
    }

    var max_count: usize = 0;
    while (value_index + max_count < value.len and tokenMatches(token, value[value_index + max_count])) : (max_count += 1) {}

    const min_count: usize = if (quantifier == '+') 1 else 0;
    if (max_count < min_count) return false;

    var count = max_count + 1;
    while (count > min_count) {
        count -= 1;
        if (matchAt(value, pattern, value_index + count, next_pattern_index, anchored_end)) return true;
    }
    return false;
}

const PatternToken = struct {
    kind: enum { literal, any, whitespace },
    literal: u8 = 0,
    pattern_len: usize,
};

fn readToken(pattern: []const u8, index: usize) PatternToken {
    if (pattern[index] == '.') {
        return .{ .kind = .any, .pattern_len = 1 };
    }
    if (pattern[index] == '\\' and index + 1 < pattern.len) {
        if (pattern[index + 1] == 's') {
            return .{ .kind = .whitespace, .pattern_len = 2 };
        }
        return .{ .kind = .literal, .literal = pattern[index + 1], .pattern_len = 2 };
    }
    return .{ .kind = .literal, .literal = pattern[index], .pattern_len = 1 };
}

fn tokenMatches(token: PatternToken, char: u8) bool {
    return switch (token.kind) {
        .literal => char == token.literal,
        .any => char != '\n' and char != '\r',
        .whitespace => std.ascii.isWhitespace(char),
    };
}
