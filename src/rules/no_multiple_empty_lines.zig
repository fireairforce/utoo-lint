const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-multiple-empty-lines";

pub const Options = struct {
    max: usize = 2,
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
    var line_start: usize = 0;
    var empty_lines: usize = 0;

    while (line_start <= source.len) {
        const line_end = findLineEnd(source, line_start);

        if (isEmptyLine(source[line_start..line_end])) {
            empty_lines += 1;
            if (empty_lines > options.max) {
                try core.addDiagnosticFmt(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    .{ .start = @intCast(line_start), .end = @intCast(line_end) },
                    "More than {d} blank lines not allowed.",
                    .{options.max},
                );
            }
        } else {
            empty_lines = 0;
        }

        if (line_end >= source.len) break;

        line_start = line_end + 1;
        if (source[line_end] == '\r' and line_start < source.len and source[line_start] == '\n') {
            line_start += 1;
        }
    }
}

fn findLineEnd(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and source[index] != '\n' and source[index] != '\r') : (index += 1) {}
    return index;
}

fn isEmptyLine(line: []const u8) bool {
    for (line) |char| {
        if (!isBlankWhitespace(char)) return false;
    }
    return true;
}

fn isBlankWhitespace(char: u8) bool {
    return char == ' ' or char == '\t' or char == 0x0B or char == 0x0C;
}
