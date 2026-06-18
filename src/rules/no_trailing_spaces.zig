const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-trailing-spaces";

pub const Options = struct {
    skip_blank_lines: bool = false,
    ignore_comments: bool = false,
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

    while (index <= source.len) {
        const line_end = findLineEnd(source, index);
        var trailing_start = line_end;

        while (trailing_start > line_start and isTrailingWhitespace(source[trailing_start - 1])) {
            trailing_start -= 1;
        }

        if (trailing_start < line_end) {
            const skip_blank_line = options.skip_blank_lines and isOnlyTrailingWhitespace(source[line_start..line_end]);
            const skip_comment = options.ignore_comments and hasIgnoredCommentOnLine(tree.comments, line_start, line_end);
            if (!skip_blank_line and !skip_comment) {
                try addDiagnostic(allocator, diagnostics, trailing_start, line_end);
            }
        }

        if (line_end >= source.len) break;

        index = line_end + 1;
        if (source[line_end] == '\r' and index < source.len and source[index] == '\n') {
            index += 1;
        }
        line_start = index;
    }
}

fn findLineEnd(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and source[index] != '\n' and source[index] != '\r') : (index += 1) {}
    return index;
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    start: usize,
    end: usize,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Trailing spaces not allowed.",
        .{ .start = @intCast(start), .end = @intCast(end) },
    );
}

fn isTrailingWhitespace(char: u8) bool {
    return char == ' ' or char == '\t' or char == 0x0B or char == 0x0C;
}

fn isOnlyTrailingWhitespace(source: []const u8) bool {
    for (source) |char| {
        if (!isTrailingWhitespace(char)) return false;
    }
    return true;
}

fn hasIgnoredCommentOnLine(comments: []const ast.Comment, line_start: usize, line_end: usize) bool {
    for (comments) |comment| {
        const start: usize = comment.start;
        const end: usize = comment.end;

        switch (comment.type) {
            .line => {
                if (line_start <= start and start <= line_end) return true;
            },
            .block => {
                if (start < line_end and end > line_end) return true;
            },
        }
    }
    return false;
}
