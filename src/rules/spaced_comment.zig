const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "spaced-comment";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    for (tree.comments) |comment| {
        if (hasExpectedSpacing(tree, comment)) continue;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Expected space or tab after comment marker.",
            .{ .start = comment.start, .end = comment.end },
        );
    }
}

fn hasExpectedSpacing(tree: *const ast.Tree, comment: ast.Comment) bool {
    const value = tree.string(comment.value);
    if (value.len == 0) return true;
    if (isWhitespace(value[0])) return true;

    return switch (comment.type) {
        .line => value[0] == '/',
        .block => value[0] == '*' or value[0] == '!',
    };
}

fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\t' or char == '\r' or char == '\n';
}
