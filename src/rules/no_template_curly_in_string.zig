const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-template-curly-in-string";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.StringLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!hasTemplateExpressionText(tree.string(literal.value))) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected template expression in regular string.",
        tree.span(index),
    );
}

fn hasTemplateExpressionText(value: []const u8) bool {
    var start: usize = 0;
    while (std.mem.indexOfPos(u8, value, start, "${")) |open| {
        if (std.mem.indexOfScalarPos(u8, value, open + 2, '}') != null) return true;
        start = open + 2;
    }
    return false;
}
