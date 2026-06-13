const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/no-unescaped-entities";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const span = tree.span(index);
    const source = sourceSlice(tree, span) orelse return;

    for (source, 0..) |byte, offset| {
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
