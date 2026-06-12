const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-nonoctal-decimal-escape";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!hasNonoctalDecimalEscape(tree, index)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Non-octal decimal escape sequences should not be used.",
        tree.span(index),
    );
}

fn hasNonoctalDecimalEscape(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (start >= end or end > tree.source.len) return false;

    const source = tree.source[start..end];
    var offset: usize = 0;
    while (offset + 1 < source.len) : (offset += 1) {
        if (source[offset] != '\\') continue;
        if (source[offset + 1] == '8' or source[offset + 1] == '9') return true;

        offset += 1;
    }

    return false;
}
