const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/jsx-filename-extension";

const allowed_extensions = [_][]const u8{
    ".jsx",
    ".js",
    ".tsx",
    ".ts",
    ".vue",
};

pub const State = struct {
    reported: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    file_path: []const u8,
    index: ast.NodeIndex,
    state: *State,
) Allocator.Error!void {
    if (state.reported or isAllowedExtension(file_path)) return;

    state.reported = true;
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "JSX not allowed in files with extension '{s}'",
        .{extension(file_path)},
    );
}

fn isAllowedExtension(file_path: []const u8) bool {
    for (&allowed_extensions) |allowed| {
        if (std.mem.endsWith(u8, file_path, allowed)) return true;
    }
    return false;
}

fn extension(file_path: []const u8) []const u8 {
    const basename = std.fs.path.basename(file_path);
    const dot_index = std.mem.lastIndexOfScalar(u8, basename, '.') orelse return "";
    if (dot_index == 0) return "";
    return basename[dot_index..];
}
