const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-tabs";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    const source = tree.source;
    var index: usize = 0;

    while (std.mem.indexOfScalarPos(u8, source, index, '\t')) |start| {
        var end = start + 1;
        while (end < source.len and source[end] == '\t') : (end += 1) {}

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Unexpected tab character.",
            .{ .start = @intCast(start), .end = @intCast(end) },
        );

        index = end;
    }
}
