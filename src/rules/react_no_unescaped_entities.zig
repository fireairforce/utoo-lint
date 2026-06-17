const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/no-unescaped-entities";

pub const Options = struct {
    forbid_gt: bool = true,
    forbid_double_quote: bool = true,
    forbid_single_quote: bool = true,
    forbid_closing_brace: bool = true,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    const span = tree.span(index);
    const source = sourceSlice(tree, span) orelse return;

    for (source, 0..) |byte, offset| {
        if (!isForbidden(byte, options)) continue;
        const alternatives = alternativesFor(byte) orelse continue;
        const start: u32 = span.start + @as(u32, @intCast(offset));
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .@"error",
            id,
            .{ .start = start, .end = start + 1 },
            "`{c}` can be escaped with {s}.",
            .{ byte, alternatives },
        );
    }
}

fn isForbidden(byte: u8, options: Options) bool {
    return switch (byte) {
        '>' => options.forbid_gt,
        '"' => options.forbid_double_quote,
        '\'' => options.forbid_single_quote,
        '}' => options.forbid_closing_brace,
        else => false,
    };
}

fn alternativesFor(byte: u8) ?[]const u8 {
    return switch (byte) {
        '>' => "`&gt;`",
        '"' => "`&quot;`, `&ldquo;`, `&#34;`, `&rdquo;`",
        '\'' => "`&apos;`, `&lsquo;`, `&#39;`, `&rsquo;`",
        '}' => "`&#125;`",
        else => null,
    };
}

fn sourceSlice(tree: *const ast.Tree, span: ast.Span) ?[]const u8 {
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (start > end or end > tree.source.len) return null;
    return tree.source[start..end];
}
