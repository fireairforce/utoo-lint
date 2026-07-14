const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-multiple-empty-lines";

pub const Options = struct {
    max: usize = 2,
    max_bof: ?usize = null,
    max_eof: ?usize = null,
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
    var empty_lines: usize = 0;

    while (line_start < source.len) {
        const line_end = findLineEnd(source, line_start);

        if (isEmptyLine(source[line_start..line_end])) {
            empty_lines += 1;
            const max = if (isLeadingEmptyLine(source, line_start))
                options.max_bof orelse options.max
            else if (isTrailingEmptyLine(source, line_start))
                options.max_eof orelse options.max
            else
                options.max;
            if (empty_lines > max) {
                try addDiagnosticWithFix(
                    allocator,
                    diagnostics,
                    line_start,
                    line_end,
                    nextLineStart(source, line_end),
                    max,
                );
            }
        } else {
            empty_lines = 0;
        }

        if (line_end >= source.len) break;

        line_start = nextLineStart(source, line_end);
    }
}

fn addDiagnosticWithFix(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    line_start: usize,
    line_end: usize,
    removal_end: usize,
    max: usize,
) Allocator.Error!void {
    const message = try std.fmt.allocPrint(allocator, "More than {d} blank lines not allowed.", .{max});
    defer allocator.free(message);

    try core.addDiagnosticWithFix(
        allocator,
        diagnostics,
        .warning,
        id,
        message,
        .{ .start = @intCast(line_start), .end = @intCast(line_end) },
        .{
            .span = .{ .start = @intCast(line_start), .end = @intCast(removal_end) },
            .replacement = "",
        },
    );
}

fn nextLineStart(source: []const u8, line_end: usize) usize {
    if (line_end >= source.len) return source.len;

    var start = line_end + 1;
    if (source[line_end] == '\r' and start < source.len and source[start] == '\n') start += 1;
    return start;
}

fn isLeadingEmptyLine(source: []const u8, line_start: usize) bool {
    for (source[0..line_start]) |char| {
        if (char == '\n' or char == '\r') continue;
        if (!isBlankWhitespace(char)) return false;
    }
    return true;
}

fn isTrailingEmptyLine(source: []const u8, line_start: usize) bool {
    for (source[line_start..]) |char| {
        if (char == '\n' or char == '\r') continue;
        if (!isBlankWhitespace(char)) return false;
    }
    return true;
}

fn findLineEnd(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and source[index] != '\n' and source[index] != '\r') : (index += 1) {}
    return index;
}

fn isEmptyLine(line: []const u8) bool {
    for (line) |char| {
        if (!isBlankWhitespace(char)) return false;
    }
    return true;
}

fn isBlankWhitespace(char: u8) bool {
    return char == ' ' or char == '\t' or char == 0x0B or char == 0x0C;
}
