const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "unicode-bom";

const bom = "\xEF\xBB\xBF";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    if (!std.mem.startsWith(u8, tree.source, bom)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected Unicode BOM (Byte Order Mark).",
        .{ .start = 0, .end = bom.len },
    );
}
