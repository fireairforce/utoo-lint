const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "max-lines";

pub const Options = struct {
    max: usize = 300,
    skip_blank_lines: bool = false,
    skip_comments: bool = false,
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
    var line_start: usize = 0;
    var index: usize = 0;
    var actual: usize = 0;
    var first_excess_start: ?usize = null;

    while (index < source.len) {
        const line_end = findLineEnd(source, index);
        const should_count = !shouldSkipLine(source, tree.comments, line_start, line_end, options);

        if (should_count) {
            actual += 1;
            if (actual == options.max + 1) {
                first_excess_start = line_start;
            }
        }

        if (line_end >= source.len) break;

        index = line_end + 1;
        if (source[line_end] == '\r' and index < source.len and source[index] == '\n') {
            index += 1;
        }
        line_start = index;
    }

    if (actual <= options.max) return;

    const start = first_excess_start orelse source.len;
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        .{ .start = @intCast(start), .end = @intCast(source.len) },
        "File has too many lines ({d}). Maximum allowed is {d}.",
        .{ actual, options.max },
    );
}

fn findLineEnd(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and source[index] != '\n' and source[index] != '\r') : (index += 1) {}
    return index;
}

fn shouldSkipLine(
    source: []const u8,
    comments: []const ast.Comment,
    line_start: usize,
    line_end: usize,
    options: Options,
) bool {
    const line = source[line_start..line_end];
    if (options.skip_blank_lines and std.mem.trim(u8, line, " \t\r\n").len == 0) return true;
    if (options.skip_comments and isCommentOnlyLine(source, comments, line_start, line_end)) return true;
    return false;
}

fn isCommentOnlyLine(
    source: []const u8,
    comments: []const ast.Comment,
    line_start: usize,
    line_end: usize,
) bool {
    var saw_comment = false;

    var index = line_start;
    while (index < line_end) : (index += 1) {
        if (std.ascii.isWhitespace(source[index])) continue;
        if (!isInsideComment(comments, index, line_start, line_end)) return false;
        saw_comment = true;
    }

    return saw_comment;
}

fn isInsideComment(
    comments: []const ast.Comment,
    index: usize,
    line_start: usize,
    line_end: usize,
) bool {
    for (comments) |comment| {
        const start: usize = comment.start;
        const end: usize = comment.end;
        if (end <= line_start or start >= line_end) continue;
        if (start <= index and index < end) return true;
    }
    return false;
}
