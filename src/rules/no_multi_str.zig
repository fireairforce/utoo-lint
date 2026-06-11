const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-multi-str";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!hasLineContinuation(tree, index)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Multiline strings are not allowed.",
        tree.span(index),
    );
}

fn hasLineContinuation(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (start >= end or end > tree.source.len) return false;

    const source = tree.source[start..end];
    var offset: usize = 0;
    while (offset < source.len) : (offset += 1) {
        if (source[offset] != '\\' or offset + 1 >= source.len) continue;

        switch (source[offset + 1]) {
            '\n', '\r' => return true,
            0xE2 => {
                if (offset + 3 >= source.len) continue;
                if (source[offset + 2] == 0x80 and
                    (source[offset + 3] == 0xA8 or source[offset + 3] == 0xA9))
                {
                    return true;
                }
            },
            else => {},
        }
    }

    return false;
}
