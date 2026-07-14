const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "eol-last";

pub const Style = enum {
    always,
    never,
};

pub const Options = struct {
    style: Style = .always,
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
    const source = tree.source;
    if (source.len == 0) return;

    switch (options.style) {
        .always => {
            if (source[source.len - 1] == '\n') return;
            try addDiagnosticWithFix(
                allocator,
                diagnostics,
                source.len - 1,
                source.len,
                "Newline required at end of file but not found.",
                source.len,
                source.len,
                "\n",
            );
        },
        .never => {
            const span = finalLinebreakSpan(source) orelse return;
            try addDiagnosticWithFix(
                allocator,
                diagnostics,
                span.start,
                span.end,
                "Newline not allowed at end of file.",
                span.start,
                span.end,
                "",
            );
        },
    }
}

const Span = struct {
    start: usize,
    end: usize,
};

fn finalLinebreakSpan(source: []const u8) ?Span {
    if (source.len == 0) return null;
    if (source[source.len - 1] == '\n') {
        const start = if (source.len >= 2 and source[source.len - 2] == '\r') source.len - 2 else source.len - 1;
        return .{ .start = start, .end = source.len };
    }
    if (source[source.len - 1] == '\r') {
        return .{ .start = source.len - 1, .end = source.len };
    }
    return null;
}

fn addDiagnosticWithFix(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    start: usize,
    end: usize,
    message: []const u8,
    fix_start: usize,
    fix_end: usize,
    replacement: []const u8,
) Allocator.Error!void {
    try core.addDiagnosticWithFix(
        allocator,
        diagnostics,
        .warning,
        id,
        message,
        .{ .start = @intCast(start), .end = @intCast(end) },
        .{
            .span = .{ .start = @intCast(fix_start), .end = @intCast(fix_end) },
            .replacement = replacement,
        },
    );
}
