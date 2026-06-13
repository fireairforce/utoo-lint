const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/ant/no-too-large-file";

const default_lines_limit = 500;

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    file_path: []const u8,
) Allocator.Error!void {
    const lines = lineCount(tree.source);
    if (lines <= default_lines_limit) return;

    const display_path = try displayPath(allocator, file_path);
    defer allocator.free(display_path);

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        .{ .start = 0, .end = 0 },
        "file: `{s}` is too large 😨 ({d} lines)`.",
        .{ display_path, lines },
    );
}

fn lineCount(source: []const u8) usize {
    var count: usize = 1;
    var index: usize = 0;
    while (index < source.len) : (index += 1) {
        if (source[index] == '\n') {
            count += 1;
        } else if (source[index] == '\r') {
            count += 1;
            if (index + 1 < source.len and source[index + 1] == '\n') index += 1;
        }
    }
    return count;
}

fn displayPath(allocator: Allocator, file_path: []const u8) Allocator.Error![]u8 {
    if (!std.fs.path.isAbsolute(file_path)) {
        return std.fmt.allocPrint(allocator, "/{s}", .{file_path});
    }

    const basename = std.fs.path.basename(file_path);
    return std.fmt.allocPrint(allocator, "/{s}", .{basename});
}
