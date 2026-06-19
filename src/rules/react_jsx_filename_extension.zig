const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/jsx-filename-extension";

pub const Options = struct {
    extensions: core.ReactJsxFilenameExtensions = .{},
    allow: core.ReactJsxFilenameExtensionAllow = .always,
};

pub const State = struct {
    reported: bool = false,
    has_jsx: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    file_path: []const u8,
    index: ast.NodeIndex,
    state: *State,
    options: Options,
) Allocator.Error!void {
    state.has_jsx = true;
    if (state.reported or options.extensions.containsFilePath(file_path)) return;

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

pub fn finish(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    file_path: []const u8,
    index: ast.NodeIndex,
    state: *State,
    options: Options,
) Allocator.Error!void {
    if (options.allow != .as_needed or state.reported or state.has_jsx) return;
    if (!options.extensions.containsFilePath(file_path)) return;

    state.reported = true;
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "Only files containing JSX may use the extension '{s}'",
        .{extension(file_path)},
    );
}

fn extension(file_path: []const u8) []const u8 {
    const basename = std.fs.path.basename(file_path);
    const dot_index = std.mem.lastIndexOfScalar(u8, basename, '.') orelse return "";
    if (dot_index == 0) return "";
    return basename[dot_index..];
}
