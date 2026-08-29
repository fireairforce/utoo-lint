const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-mixed-spaces-and-tabs";

pub const Options = struct {
    smart_tabs: bool = false,
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
    var ignored_literal_spans: std.ArrayList(ast.Span) = .empty;
    defer ignored_literal_spans.deinit(allocator);
    try collectIgnoredLiteralSpans(allocator, tree, &ignored_literal_spans);

    var line_start: usize = 0;
    var comment_index: usize = 0;
    var literal_index: usize = 0;

    while (line_start <= source.len) {
        const line_end = findLineEnd(source, line_start);
        if (!isIgnoredCommentLine(tree.comments, line_start, &comment_index)) {
            if (mixedIndentSpan(source, line_start, line_end, options.smart_tabs)) |span| {
                if (!isInsideIgnoredLiteral(ignored_literal_spans.items, span.start, &literal_index)) {
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

fn mixedIndentSpan(source: []const u8, line_start: usize, line_end: usize, smart_tabs: bool) ?ast.Span {
    if (line_start >= line_end) return null;

    const first = source[line_start];
    if (!isIndent(first)) return null;

    var index = line_start + 1;
    while (index < line_end and source[index] == first) : (index += 1) {}

    if (index >= line_end or !isIndent(source[index])) return null;
    if (smart_tabs and first == '\t' and source[index] == ' ') return null;

    const end = index + 1;
    return .{
        .start = @intCast(end - 2),
        .end = @intCast(end),
    };
}

fn isIgnoredCommentLine(comments: []const ast.Comment, line_start: usize, cursor: *usize) bool {
    while (cursor.* < comments.len) {
        const comment = comments[cursor.*];
        if (comment.span.end < line_start) {
            cursor.* += 1;
            continue;
        }
        if (comment.span.start >= line_start) return false;
        if (comment.type == .block) return true;
        cursor.* += 1;
    }
    return false;
}

fn collectIgnoredLiteralSpans(
    allocator: Allocator,
    tree: *const ast.Tree,
    spans: *std.ArrayList(ast.Span),
) Allocator.Error!void {
    const data = tree.nodes.items(.data);
    const node_spans = tree.nodes.items(.span);

    for (data, node_spans) |node, span| {
        switch (node) {
            .string_literal, .template_element => try spans.append(allocator, span),
            else => {},
        }
    }

    std.mem.sort(ast.Span, spans.items, {}, spanLessThan);
}

fn isInsideIgnoredLiteral(spans: []const ast.Span, offset: u32, cursor: *usize) bool {
    while (cursor.* < spans.len and spans[cursor.*].end <= offset) cursor.* += 1;

    var index = cursor.*;
    while (index < spans.len and spans[index].start <= offset) : (index += 1) {
        if (offset < spans[index].end) {
            cursor.* = index;
            return true;
        }
    }

    cursor.* = index;
    return false;
}

fn spanLessThan(_: void, left: ast.Span, right: ast.Span) bool {
    return left.start < right.start or (left.start == right.start and left.end > right.end);
}

fn findLineEnd(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and source[index] != '\n' and source[index] != '\r') : (index += 1) {}
    return index;
}

fn isIndent(char: u8) bool {
    return char == ' ' or char == '\t';
}
