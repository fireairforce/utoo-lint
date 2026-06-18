const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "unicode-bom";

const bom = "\xEF\xBB\xBF";

pub const Style = enum {
    never,
    always,
};

pub const Options = struct {
    style: Style = .never,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    try runWithOptions(allocator, diagnostics, tree, .{});
}

pub fn runWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    options: Options,
) Allocator.Error!void {
    const has_bom = std.mem.startsWith(u8, tree.source, bom);
    switch (options.style) {
        .never => {
            if (!has_bom) return;
            try addDiagnostic(allocator, diagnostics, 0, bom.len, "Unexpected Unicode BOM (Byte Order Mark).");
        },
        .always => {
            if (has_bom) return;
            try addDiagnostic(allocator, diagnostics, 0, @min(tree.source.len, 1), "Expected Unicode BOM (Byte Order Mark).");
        },
    }
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    start: usize,
    end: usize,
    message: []const u8,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        message,
        .{ .start = @intCast(start), .end = @intCast(end) },
    );
}
