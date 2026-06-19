const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "max-lines-per-function";

pub const Options = struct {
    max: usize = 50,
    skip_blank_lines: bool = false,
    skip_comments: bool = false,
    iifes: bool = false,
};

pub fn checkFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (!options.iifes and isIife(tree, index, ctx)) return;
    try checkSpan(allocator, diagnostics, tree, index, tree.span(index), options);
}

pub fn checkArrowFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (!options.iifes and isIife(tree, index, ctx)) return;
    try checkSpan(allocator, diagnostics, tree, index, tree.span(index), options);
}

fn checkSpan(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    span: ast.Span,
    options: Options,
) Allocator.Error!void {
    const source = tree.source;
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (start >= source.len or end <= start) return;

    var line_start = lineStart(source, start);
    const final = @min(end, source.len);
    var actual: usize = 0;

    while (line_start < final) {
        const line_end = findLineEnd(source, line_start);
        if (!shouldSkipLine(source, tree.comments, line_start, @min(line_end, final), options)) {
            actual += 1;
        }

        if (line_end >= source.len or line_end >= final) break;

        line_start = line_end + 1;
        if (source[line_end] == '\r' and line_start < source.len and source[line_start] == '\n') {
            line_start += 1;
        }
    }

    if (actual <= options.max) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Function has too many lines ({d}). Maximum allowed is {d}.",
        .{ actual, options.max },
    );
}

fn lineStart(source: []const u8, offset: usize) usize {
    var index = @min(offset, source.len);
    while (index > 0 and source[index - 1] != '\n' and source[index - 1] != '\r') : (index -= 1) {}
    return index;
}

fn findLineEnd(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and source[index] != '\n' and source[index] != '\r') : (index += 1) {}
    return index;
}

fn shouldSkipLine(
    source: []const u8,
    comments: []const ast.Comment,
    line_start: usize,
    line_end: usize,
    options: Options,
) bool {
    const line = source[line_start..line_end];
    if (options.skip_blank_lines and std.mem.trim(u8, line, " \t\r\n").len == 0) return true;
    if (options.skip_comments and isCommentOnlyLine(source, comments, line_start, line_end)) return true;
    return false;
}

fn isCommentOnlyLine(
    source: []const u8,
    comments: []const ast.Comment,
    line_start: usize,
    line_end: usize,
) bool {
    var saw_comment = false;

    var index = line_start;
    while (index < line_end) : (index += 1) {
        if (std.ascii.isWhitespace(source[index])) continue;
        if (!isInsideComment(comments, index, line_start, line_end)) return false;
        saw_comment = true;
    }

    return saw_comment;
}

fn isInsideComment(
    comments: []const ast.Comment,
    index: usize,
    line_start: usize,
    line_end: usize,
) bool {
    for (comments) |comment| {
        const start: usize = comment.start;
        const end: usize = comment.end;
        if (end <= line_start or start >= line_end) continue;
        if (start <= index and index < end) return true;
    }
    return false;
}

fn isIife(tree: *const ast.Tree, index: ast.NodeIndex, ctx: *traverser.basic.Ctx) bool {
    var current = index;
    var depth: usize = 1;

    while (ctx.path.ancestor(depth)) |parent| : (depth += 1) {
        switch (tree.data(parent)) {
            .parenthesized_expression => |parenthesized| {
                if (parenthesized.expression != current) return isIifeBySource(tree, index);
                current = parent;
            },
            .chain_expression => |chain| {
                if (chain.expression != current) return isIifeBySource(tree, index);
                current = parent;
            },
            .call_expression => |call| return unwrapTransparent(tree, call.callee) == current or isIifeBySource(tree, index),
            else => return isIifeBySource(tree, index),
        }
    }

    return isIifeBySource(tree, index);
}

fn isIifeBySource(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const source = tree.source;
    const span = tree.span(index);
    var cursor: usize = @intCast(span.end);

    while (cursor < source.len) : (cursor += 1) {
        switch (source[cursor]) {
            ' ', '\t', '\r', '\n' => continue,
            ')' => continue,
            '(' => return true,
            else => return false,
        }
    }

    return false;
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;

    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |chain| current = chain.expression,
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            else => return current,
        }
    }

    return current;
}
