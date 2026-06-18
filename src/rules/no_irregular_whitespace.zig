const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-irregular-whitespace";

pub const Options = struct {
    skip_strings: bool = true,
    skip_comments: bool = false,
    skip_reg_exps: bool = false,
    skip_templates: bool = false,
    skip_jsx_text: bool = false,
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
    var index: usize = 0;

    while (index < source.len) {
        if (irregularWhitespaceLen(source[index..])) |len| {
            const end = index + len;
            if (!isInsideIgnoredSpan(tree, @intCast(index), options)) {
                try core.addDiagnostic(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    "Irregular whitespace not allowed.",
                    .{ .start = @intCast(index), .end = @intCast(end) },
                );
            }
            index = end;
            continue;
        }

        index += 1;
    }
}

fn irregularWhitespaceLen(source: []const u8) ?usize {
    if (source.len == 0) return null;

    switch (source[0]) {
        0x0B, 0x0C => return 1,
        0xC2 => {
            if (startsWith(source, &.{ 0xC2, 0x85 }) or startsWith(source, &.{ 0xC2, 0xA0 })) return 2;
        },
        0xE1 => {
            if (startsWith(source, &.{ 0xE1, 0x9A, 0x80 }) or startsWith(source, &.{ 0xE1, 0xA0, 0x8E })) return 3;
        },
        0xE2 => {
            if (source.len >= 3 and source[1] == 0x80 and source[2] >= 0x80 and source[2] <= 0x8B) return 3;
            if (startsWith(source, &.{ 0xE2, 0x80, 0xA8 }) or
                startsWith(source, &.{ 0xE2, 0x80, 0xA9 }) or
                startsWith(source, &.{ 0xE2, 0x80, 0xAF }) or
                startsWith(source, &.{ 0xE2, 0x81, 0x9F }))
            {
                return 3;
            }
        },
        0xE3 => {
            if (startsWith(source, &.{ 0xE3, 0x80, 0x80 })) return 3;
        },
        0xEF => {
            if (startsWith(source, &.{ 0xEF, 0xBB, 0xBF })) return 3;
        },
        else => {},
    }

    return null;
}

fn startsWith(source: []const u8, bytes: []const u8) bool {
    return std.mem.startsWith(u8, source, bytes);
}

fn isInsideIgnoredSpan(tree: *const ast.Tree, offset: u32, options: Options) bool {
    if (options.skip_comments) {
        for (tree.comments) |comment| {
            if (comment.start <= offset and offset < comment.end) return true;
        }
    }

    const data = tree.nodes.items(.data);
    const spans = tree.nodes.items(.span);

    for (data, spans) |node, span| {
        switch (node) {
            .string_literal => {
                if (options.skip_strings and containsOffset(span, offset)) return true;
            },
            .regexp_literal => {
                if (options.skip_reg_exps and containsOffset(span, offset)) return true;
            },
            .template_element => {
                if (options.skip_templates and containsOffset(span, offset)) return true;
            },
            .jsx_text => {
                if (options.skip_jsx_text and containsOffset(span, offset)) return true;
            },
            else => {},
        }
    }

    return false;
}

fn containsOffset(span: ast.Span, offset: u32) bool {
    return span.start <= offset and offset < span.end;
}
