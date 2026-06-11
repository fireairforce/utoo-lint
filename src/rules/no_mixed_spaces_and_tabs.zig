const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-mixed-spaces-and-tabs";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    const source = tree.source;
    var line_start: usize = 0;
    var line_number: usize = 1;

    while (line_start <= source.len) : (line_number += 1) {
        const line_end = findLineEnd(source, line_start);
        if (!isIgnoredCommentLine(source, tree.comments, line_number)) {
            if (mixedIndentSpan(source, line_start, line_end)) |span| {
                if (!isInsideIgnoredLiteral(tree, span.start)) {
                    try core.addDiagnostic(
                        allocator,
                        diagnostics,
                        .warning,
                        id,
                        "Mixed spaces and tabs.",
                        span,
                    );
                }
            }
        }

        if (line_end >= source.len) break;

        line_start = line_end + 1;
        if (source[line_end] == '\r' and line_start < source.len and source[line_start] == '\n') {
            line_start += 1;
        }
    }
}

fn mixedIndentSpan(source: []const u8, line_start: usize, line_end: usize) ?ast.Span {
    if (line_start >= line_end) return null;

    const first = source[line_start];
    if (!isIndent(first)) return null;

    var index = line_start + 1;
    while (index < line_end and source[index] == first) : (index += 1) {}

    if (index >= line_end or !isIndent(source[index])) return null;

    const end = index + 1;
    return .{
        .start = @intCast(end - 2),
        .end = @intCast(end),
    };
}

fn isIgnoredCommentLine(source: []const u8, comments: []const ast.Comment, line_number: usize) bool {
    for (comments) |comment| {
        if (comment.type != .block) continue;

        const start_line = lineNumberAtOffset(source, comment.start);
        if (line_number <= start_line) continue;

        const end_line = lineNumberAtOffset(source, comment.end);
        if (line_number <= end_line) return true;
    }

    return false;
}

fn isInsideIgnoredLiteral(tree: *const ast.Tree, offset: u32) bool {
    const data = tree.nodes.items(.data);
    const spans = tree.nodes.items(.span);

    for (data, spans) |node, span| {
        switch (node) {
            .string_literal, .template_element => {
                if (span.start <= offset and offset < span.end) return true;
            },
            else => {},
        }
    }

    return false;
}

fn lineNumberAtOffset(source: []const u8, offset: u32) usize {
    var line: usize = 1;
    var index: usize = 0;
    const end: usize = @min(offset, source.len);

    while (index < end) : (index += 1) {
        if (source[index] == '\n') line += 1;
    }

    return line;
}

fn findLineEnd(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and source[index] != '\n' and source[index] != '\r') : (index += 1) {}
    return index;
}

fn isIndent(char: u8) bool {
    return char == ' ' or char == '\t';
}
