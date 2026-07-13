const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-multi-spaces";

pub const Options = struct {
    ignore_eol_comments: core.NoMultiSpacesIgnoreEOLComments = .no,
    exceptions: core.NoMultiSpacesExceptions = .{},
};

const IgnoredSpan = struct {
    start: u32,
    end: u32,
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
    const ignored_spans = try collectIgnoredSpans(allocator, tree, options);
    defer allocator.free(ignored_spans);

    var line_start: usize = 0;
    var ignored_index: usize = 0;

    while (line_start <= source.len) {
        const line_end = findLineEnd(source, line_start);
        try checkLine(allocator, diagnostics, tree, line_start, line_end, ignored_spans, &ignored_index, options);

        if (line_end >= source.len) break;

        line_start = line_end + 1;
        if (source[line_end] == '\r' and line_start < source.len and source[line_start] == '\n') {
            line_start += 1;
        }
    }
}

fn checkLine(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    line_start: usize,
    line_end: usize,
    ignored_spans: []const IgnoredSpan,
    ignored_index: *usize,
    options: Options,
) Allocator.Error!void {
    const source = tree.source;
    var index = line_start;

    while (index < line_end and (source[index] == ' ' or source[index] == '\t')) : (index += 1) {}

    while (index < line_end) {
        while (ignored_index.* < ignored_spans.len and ignored_spans[ignored_index.*].end <= index) {
            ignored_index.* += 1;
        }

        if (ignored_index.* < ignored_spans.len) {
            const span = ignored_spans[ignored_index.*];
            if (span.start <= index and index < span.end) {
                index = @min(line_end, @as(usize, @intCast(span.end)));
                continue;
            }
        }

        if (source[index] != ' ') {
            index += 1;
            continue;
        }

        const start = index;
        while (index < line_end and source[index] == ' ') : (index += 1) {}

        if (index - start > 1) {
            if (options.ignore_eol_comments == .yes and isBeforeEndOfLineComment(tree, index, line_end)) continue;

            try core.addDiagnostic(
                allocator,
                diagnostics,
                .warning,
                id,
                "Multiple spaces found before.",
                .{ .start = @intCast(start), .end = @intCast(index) },
            );
        }
    }
}

fn isBeforeEndOfLineComment(tree: *const ast.Tree, index: usize, line_end: usize) bool {
    for (tree.comments) |comment| {
        const start: usize = comment.span.start;
        if (start != index) continue;
        if (comment.type == .line) return true;

        const end: usize = comment.span.end;
        if (end > line_end) return false;
        return isOnlyWhitespace(tree.source[end..line_end]);
    }
    return false;
}

fn isOnlyWhitespace(source: []const u8) bool {
    for (source) |byte| {
        if (byte != ' ' and byte != '\t') return false;
    }
    return true;
}

fn collectIgnoredSpans(allocator: Allocator, tree: *const ast.Tree, options: Options) Allocator.Error![]IgnoredSpan {
    var ignored_spans: std.ArrayList(IgnoredSpan) = .empty;
    errdefer ignored_spans.deinit(allocator);

    for (tree.comments) |comment| {
        try ignored_spans.append(allocator, .{ .start = comment.span.start, .end = comment.span.end });
    }

    const data = tree.nodes.items(.data);
    const spans = tree.nodes.items(.span);
    for (data, spans) |node, span| {
        switch (node) {
            .string_literal, .template_element, .regexp_literal => {
                try ignored_spans.append(allocator, .{ .start = span.start, .end = span.end });
            },
            .binary_expression => {
                if (options.exceptions.binary_expression) {
                    try ignored_spans.append(allocator, .{ .start = span.start, .end = span.end });
                }
            },
            .variable_declarator => {
                if (options.exceptions.variable_declarator) {
                    try ignored_spans.append(allocator, .{ .start = span.start, .end = span.end });
                }
            },
            .import_declaration => {
                if (options.exceptions.import_declaration) {
                    try ignored_spans.append(allocator, .{ .start = span.start, .end = span.end });
                }
            },
            .object_property => |property| {
                if (!options.exceptions.property) continue;
                const value_span = tree.span(property.value);
                if (span.start < value_span.start) {
                    try ignored_spans.append(allocator, .{ .start = span.start, .end = value_span.start });
                }
            },
            else => {},
        }
    }

    const items = try ignored_spans.toOwnedSlice(allocator);
    std.mem.sort(IgnoredSpan, items, {}, ignoredSpanLessThan);
    return items;
}

fn ignoredSpanLessThan(_: void, lhs: IgnoredSpan, rhs: IgnoredSpan) bool {
    return lhs.start < rhs.start or (lhs.start == rhs.start and lhs.end < rhs.end);
}

fn findLineEnd(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and source[index] != '\n' and source[index] != '\r') : (index += 1) {}
    return index;
}
