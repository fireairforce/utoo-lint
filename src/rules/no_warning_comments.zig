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

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    for (tree.comments) |comment| {
        const match = warningTermAtStart(tree, comment) orelse continue;

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

fn warningTermAtStart(tree: *const ast.Tree, comment: ast.Comment) ?[]const u8 {
    const value = tree.string(comment.value);
    const trimmed = trimLeftWhitespace(value);

    inline for (terms) |term| {
        if (startsWithWholeWordIgnoreCase(trimmed, term)) return term;
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
    if (value.len < term.len) return false;
    if (!std.ascii.eqlIgnoreCase(value[0..term.len], term)) return false;
    if (value.len == term.len) return true;

    return !isAsciiIdentifierPart(value[term.len]);
}

fn isAsciiIdentifierPart(char: u8) bool {
    return std.ascii.isAlphanumeric(char) or char == '_' or char == '$';
}
