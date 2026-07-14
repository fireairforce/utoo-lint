const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-div-regex";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.RegExpLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const pattern = tree.string(literal.pattern);
    if (pattern.len == 0 or pattern[0] != '=') return;

    const span = tree.span(index);
    try core.addDiagnosticWithFix(
        allocator,
        diagnostics,
        .warning,
        id,
        "A regular expression literal can be confused with '/='.",
        span,
        .{
            .span = .{ .start = span.start + 1, .end = span.start + 2 },
            .replacement = "[=]",
        },
    );
}
