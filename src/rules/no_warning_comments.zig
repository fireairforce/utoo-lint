const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-warning-comments";

const terms = [_][]const u8{
    "todo",
    "fixme",
    "xxx",
};

pub const Location = enum {
    start,
    anywhere,
};

pub const Options = struct {
    location: Location = .start,
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
    for (tree.comments) |comment| {
        const match = warningTerm(tree, comment, options.location) orelse continue;

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            .{ .start = comment.start, .end = comment.end },
            "Unexpected '{s}' comment.",
            .{match},
        );
    }
}

fn warningTerm(tree: *const ast.Tree, comment: ast.Comment, location: Location) ?[]const u8 {
    return switch (location) {
        .start => warningTermAtStart(tree, comment),
        .anywhere => warningTermAnywhere(tree, comment),
    };
}

fn warningTermAtStart(tree: *const ast.Tree, comment: ast.Comment) ?[]const u8 {
    const value = tree.string(comment.value);
    const trimmed = trimLeftWhitespace(value);

    inline for (terms) |term| {
        if (startsWithWholeWordIgnoreCase(trimmed, term)) return term;
    }

    return null;
}

fn warningTermAnywhere(tree: *const ast.Tree, comment: ast.Comment) ?[]const u8 {
    const value = tree.string(comment.value);
    var index: usize = 0;

    while (index < value.len) : (index += 1) {
        inline for (terms) |term| {
            if (matchesWholeWordAt(value, index, term)) return term;
        }
    }

    return null;
}

fn trimLeftWhitespace(value: []const u8) []const u8 {
    var index: usize = 0;
    while (index < value.len and isWhitespace(value[index])) : (index += 1) {}
    return value[index..];
}

fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\t' or char == '\r' or char == '\n';
}

fn startsWithWholeWordIgnoreCase(value: []const u8, term: []const u8) bool {
    return matchesWholeWordAt(value, 0, term);
}

fn matchesWholeWordAt(value: []const u8, index: usize, term: []const u8) bool {
    if (index > value.len) return false;
    if (index != 0 and isAsciiIdentifierPart(value[index - 1])) return false;
    const remaining = value[index..];
    if (remaining.len < term.len) return false;
    if (!std.ascii.eqlIgnoreCase(remaining[0..term.len], term)) return false;
    if (remaining.len == term.len) return true;

    return !isAsciiIdentifierPart(remaining[term.len]);
}

fn isAsciiIdentifierPart(char: u8) bool {
    return std.ascii.isAlphanumeric(char) or char == '_' or char == '$';
}
