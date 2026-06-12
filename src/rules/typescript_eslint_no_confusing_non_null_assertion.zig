const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-confusing-non-null-assertion";

pub fn checkBinaryExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    switch (expression.operator) {
        .equal, .strict_equal => {},
        else => return,
    }

    if (!hasConfusingLeftNonNullAssertion(tree, expression.left)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Confusing combinations of non-null assertion and equal test like \"a! == b\", which looks very similar to not equal \"a !== b\".",
        tree.span(index),
    );
}

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (expression.operator != .assign) return;
    if (!hasConfusingLeftNonNullAssertion(tree, expression.left)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Confusing combinations of non-null assertion and equal test like \"a! = b\", which looks very similar to not equal \"a != b\".",
        tree.span(index),
    );
}

fn hasConfusingLeftNonNullAssertion(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    const span = tree.span(index);
    if (span.start >= span.end or span.end > tree.source.len) return false;

    if (previousNonWhitespace(tree.source[span.start..span.end]) != '!') return false;
    return nextNonWhitespace(tree.source[span.end..]) != ')';
}

fn previousNonWhitespace(source: []const u8) ?u8 {
    var index = source.len;
    while (index > 0) {
        index -= 1;
        const char = source[index];
        if (!isWhitespace(char)) return char;
    }
    return null;
}

fn nextNonWhitespace(source: []const u8) ?u8 {
    var index: usize = 0;
    while (index < source.len) : (index += 1) {
        const char = source[index];
        if (!isWhitespace(char)) return char;
    }
    return null;
}

fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\t' or char == '\r' or char == '\n';
}
