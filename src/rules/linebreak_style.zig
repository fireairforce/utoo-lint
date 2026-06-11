const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "linebreak-style";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    const source = tree.source;
    var index: usize = 0;

    while (std.mem.indexOfPos(u8, source, index, "\r\n")) |start| {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Expected linebreaks to be 'LF' but found 'CRLF'.",
            .{ .start = @intCast(start), .end = @intCast(start + 2) },
        );

        index = start + 2;
    }
}
