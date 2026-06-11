const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "eol-last";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    const source = tree.source;
    if (source.len == 0 or source[source.len - 1] == '\n') return;

    const start = source.len - 1;
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Newline required at end of file but not found.",
        .{ .start = @intCast(start), .end = @intCast(source.len) },
    );
}
