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
    try checkSpan(allocator, diagnostics, tree, tree.span(index), options);
}

pub fn checkElement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    element: ast.JSXElement,
    options: Options,
) Allocator.Error!void {
    if (element.closing_element == .null) return;

    try checkChildren(
        allocator,
        diagnostics,
        tree,
        tree.span(element.opening_element).end,
        tree.span(element.closing_element).start,
        element.children,
        options,
    );
}

pub fn checkFragment(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    fragment: ast.JSXFragment,
    options: Options,
) Allocator.Error!void {
    try checkChildren(
        allocator,
        diagnostics,
        tree,
        tree.span(fragment.opening_fragment).end,
        tree.span(fragment.closing_fragment).start,
        fragment.children,
        options,
    );
}

fn checkChildren(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    content_start: u32,
    content_end: u32,
    children: ast.IndexRange,
    options: Options,
) Allocator.Error!void {
    if (content_start > content_end) return;

    const gap_options = Options{
        .forbid_gt = options.forbid_gt,
        .forbid_double_quote = false,
        .forbid_single_quote = false,
        .forbid_closing_brace = options.forbid_closing_brace,
    };
    var cursor = content_start;

    for (tree.extra(children)) |child| {
        const child_span = tree.span(child);
        if (cursor < child_span.start) {
            try checkSpan(
                allocator,
                diagnostics,
                tree,
                .{ .start = cursor, .end = child_span.start },
                gap_options,
            );
        }
        if (tree.data(child) == .jsx_text) {
            try checkSpan(allocator, diagnostics, tree, child_span, options);
        }
        cursor = @max(cursor, child_span.end);
    }

    if (cursor < content_end) {
        try checkSpan(
            allocator,
            diagnostics,
            tree,
            .{ .start = cursor, .end = content_end },
            gap_options,
        );
    }
}

fn checkSpan(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    span: ast.Span,
    options: Options,
) Allocator.Error!void {
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
