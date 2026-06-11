const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-multi-spaces";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    const source = tree.source;
    var line_start: usize = 0;

    while (line_start <= source.len) {
        const line_end = findLineEnd(source, line_start);
        try checkLine(allocator, diagnostics, tree, line_start, line_end);

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
) Allocator.Error!void {
    const source = tree.source;
    var index = line_start;

    while (index < line_end and (source[index] == ' ' or source[index] == '\t')) : (index += 1) {}

    while (index < line_end) {
        if (source[index] != ' ' or isInsideIgnoredSpan(tree, @intCast(index))) {
            index += 1;
            continue;
        }

        const start = index;
        while (index < line_end and source[index] == ' ') : (index += 1) {}

        if (index - start > 1) {
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

fn isInsideIgnoredSpan(tree: *const ast.Tree, offset: u32) bool {
    for (tree.comments) |comment| {
        if (comment.start <= offset and offset < comment.end) return true;
    }

    const data = tree.nodes.items(.data);
    const spans = tree.nodes.items(.span);
    for (data, spans) |node, span| {
        switch (node) {
            .string_literal, .template_element, .regexp_literal => {
                if (span.start <= offset and offset < span.end) return true;
            },
            else => {},
        }
    }

    return false;
}

fn findLineEnd(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and source[index] != '\n' and source[index] != '\r') : (index += 1) {}
    return index;
}
