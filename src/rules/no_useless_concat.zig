const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-useless-concat";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (expression.operator != .add) return;
    if (!isStringLikeLiteral(tree, expression.left)) return;
    if (!isStringLikeLiteral(tree, expression.right)) return;
    if (!sameLine(tree, expression.left, expression.right)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected string literal concatenation.",
        tree.span(index),
    );
}

fn isStringLikeLiteral(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .string_literal => true,
        .template_literal => true,
        else => false,
    };
}

fn sameLine(tree: *const ast.Tree, left: ast.NodeIndex, right: ast.NodeIndex) bool {
    const left_span = tree.span(unwrapTransparent(tree, left));
    const right_span = tree.span(unwrapTransparent(tree, right));
    const left_end: usize = @intCast(left_span.end);
    const right_start: usize = @intCast(right_span.start);
    if (left_end > right_start or right_start > tree.source.len) return false;

    return !containsLineTerminator(tree.source[left_end..right_start]);
}

fn containsLineTerminator(source: []const u8) bool {
    for (source) |byte| {
        if (byte == '\n' or byte == '\r') return true;
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
