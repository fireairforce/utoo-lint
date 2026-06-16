const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "spaced-comment";

pub const Style = enum {
    always,
    never,
};

pub const Options = struct {
    style: Style = .always,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    return runWithOptions(allocator, diagnostics, tree, .{});
}

pub fn runWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    options: Options,
) Allocator.Error!void {
    for (tree.comments) |comment| {
        if (hasExpectedSpacing(tree, comment, options.style)) continue;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            message(options.style),
            .{ .start = comment.start, .end = comment.end },
        );
    }
}

fn hasExpectedSpacing(tree: *const ast.Tree, comment: ast.Comment, style: Style) bool {
    const value = tree.string(comment.value);
    if (value.len == 0) return true;

    const index = spacingIndex(value, comment.type);
    if (index >= value.len) return true;

    return switch (style) {
        .always => isWhitespace(value[index]),
        .never => !isWhitespace(value[index]),
    };
}

fn spacingIndex(value: []const u8, comment_type: ast.Comment.Type) usize {
    if (comment_type == .block and value[0] == '*') return 1;
    return 0;
}

fn message(style: Style) []const u8 {
    return switch (style) {
        .always => "Expected space or tab after comment marker.",
        .never => "Expected no space or tab after comment marker.",
    };
}

fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\t' or char == '\r' or char == '\n';
}
