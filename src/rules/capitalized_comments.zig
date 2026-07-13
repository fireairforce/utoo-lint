const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "capitalized-comments";

pub const Mode = enum {
    always,
    never,
};

pub const Options = struct {
    mode: Mode = .always,
    ignore_inline_comments: bool = false,
    ignore_consecutive_comments: bool = false,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    return runWithOptions(allocator, diagnostics, tree, .{});
}

pub fn runWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    options: Options,
) Allocator.Error!void {
    var previous_comment: ?ast.Comment = null;

    for (tree.comments) |comment| {
        const consecutive = if (previous_comment) |previous|
            isConsecutiveComment(tree, previous, comment)
        else
            false;
        previous_comment = comment;

        if (options.ignore_inline_comments and isInlineComment(tree, comment)) continue;
        if (options.ignore_consecutive_comments and consecutive) continue;

        const value = trimLeftDecorations(tree.string(comment.value));
        if (isIgnoredComment(value)) continue;

        const first = firstAsciiLetter(value) orelse continue;
        if (!violatesMode(first, options.mode)) continue;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            diagnosticMessage(options.mode),
            .{ .start = comment.span.start, .end = comment.span.end },
        );
    }
}

fn diagnosticMessage(mode: Mode) []const u8 {
    return switch (mode) {
        .always => "Comments should start with an uppercase character.",
        .never => "Comments should not start with an uppercase character.",
    };
}

fn isConsecutiveComment(tree: *const ast.Tree, previous: ast.Comment, current: ast.Comment) bool {
    if (previous.span.end > current.span.start) return false;

    for (tree.source[previous.span.end..current.span.start]) |char| {
        if (!isWhitespace(char)) return false;
    }
    return true;
}

fn violatesMode(first: u8, mode: Mode) bool {
    return switch (mode) {
        .always => std.ascii.isLower(first),
        .never => std.ascii.isUpper(first),
    };
}

fn isInlineComment(tree: *const ast.Tree, comment: ast.Comment) bool {
    return hasNonWhitespaceBeforeOnLine(tree.source, comment.span.start) and
        hasNonWhitespaceAfterOnLine(tree.source, comment.span.end);
}

fn hasNonWhitespaceBeforeOnLine(source: []const u8, offset: usize) bool {
    var cursor = offset;
    while (cursor > 0) {
        cursor -= 1;
        const char = source[cursor];
        if (char == '\n' or char == '\r') return false;
        if (!isWhitespace(char)) return true;
    }
    return false;
}

fn hasNonWhitespaceAfterOnLine(source: []const u8, offset: usize) bool {
    var cursor = offset;
    while (cursor < source.len) : (cursor += 1) {
        const char = source[cursor];
        if (char == '\n' or char == '\r') return false;
        if (!isWhitespace(char)) return true;
    }
    return false;
}

fn trimLeftDecorations(value: []const u8) []const u8 {
    var index: usize = 0;
    while (index < value.len) : (index += 1) {
        const char = value[index];
        if (isWhitespace(char) or char == '*') continue;
        return value[index..];
    }
    return "";
}

fn isIgnoredComment(value: []const u8) bool {
    if (startsWithAnyIgnoreCase(value, &.{
        "eslint",
        "exported",
        "global",
        "globals",
        "jshint",
        "jslint",
    })) return true;

    return startsWithAnyIgnoreCase(value, &.{
        "http://",
        "https://",
        "ftp://",
        "www.",
    });
}

fn startsWithAnyIgnoreCase(value: []const u8, prefixes: []const []const u8) bool {
    for (prefixes) |prefix| {
        if (value.len < prefix.len) continue;
        if (std.ascii.eqlIgnoreCase(value[0..prefix.len], prefix)) return true;
    }
    return false;
}

fn firstAsciiLetter(value: []const u8) ?u8 {
    var index: usize = 0;
    while (index < value.len) : (index += 1) {
        const char = value[index];
        if (std.ascii.isAlphabetic(char)) return char;
        if (std.ascii.isDigit(char)) return null;
        if (char == '_' or char == '$') return null;
    }
    return null;
}

fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\t' or char == '\r' or char == '\n';
}
