const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-tabs";

pub const Options = struct {
    allow_indentation_tabs: bool = false,
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
    var index: usize = 0;
    var line_indentation = true;

    while (index < source.len) {
        const char = source[index];
        if (char == '\n' or char == '\r') {
            index += 1;
            line_indentation = true;
            continue;
        }
        if (line_indentation and char == ' ') {
            index += 1;
            continue;
        }
        if (char != '\t') {
            line_indentation = false;
            index += 1;
            continue;
        }

        const allowed = options.allow_indentation_tabs and line_indentation;
        var end = index + 1;
        while (end < source.len and source[end] == '\t') : (end += 1) {}
        if (allowed) {
            index = end;
            continue;
        }

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Unexpected tab character.",
            .{ .start = @intCast(index), .end = @intCast(end) },
        );

        index = end;
        line_indentation = false;
    }
}
