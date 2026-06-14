const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "capitalized-comments";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    for (tree.comments) |comment| {
        const value = trimLeftDecorations(tree.string(comment.value));
        if (isIgnoredComment(value)) continue;

        const first = firstAsciiLetter(value) orelse continue;
        if (!std.ascii.isLower(first)) continue;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Comments should start with an uppercase character.",
            .{ .start = comment.start, .end = comment.end },
        );
    }
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
