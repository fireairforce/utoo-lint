const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-inline-comments";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
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
