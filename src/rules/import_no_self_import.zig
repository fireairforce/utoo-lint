const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "import/no-self-import";

const extensions = [_][]const u8{
    ".ts",
    ".cts",
    ".mts",
    ".tsx",
    ".js",
    ".jsx",
    ".mjs",
    ".cjs",
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    program: ast.Program,
    file_path: []const u8,
) Allocator.Error!void {
    const current_path = try std.fs.path.resolve(allocator, &.{file_path});
    defer allocator.free(current_path);

    for (tree.extra(program.body)) |statement_index| {
        const declaration = switch (tree.data(statement_index)) {
            .import_declaration => |declaration| declaration,
            else => continue,
        };
        const source = importSource(tree, declaration) orelse continue;
        if (!isRelativeImport(source)) continue;

        if (try resolvesToCurrentFile(allocator, file_path, source, current_path)) {
            try core.addDiagnostic(
                allocator,
                diagnostics,
                .@"error",
                id,
                "Module imports itself.",
                tree.span(statement_index),
            );
        }
    }
}

fn importSource(tree: *const ast.Tree, declaration: ast.ImportDeclaration) ?[]const u8 {
    return switch (tree.data(declaration.source)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn isRelativeImport(source: []const u8) bool {
    return std.mem.startsWith(u8, source, "./") or
        std.mem.startsWith(u8, source, "../") or
        std.mem.eql(u8, source, ".") or
        std.mem.eql(u8, source, "..");
}

fn resolvesToCurrentFile(
    allocator: Allocator,
    file_path: []const u8,
    source: []const u8,
    current_path: []const u8,
) Allocator.Error!bool {
    const directory = std.fs.path.dirname(file_path) orelse ".";
    const imported_path = try std.fs.path.resolve(allocator, &.{ directory, source });
    defer allocator.free(imported_path);

    if (std.mem.eql(u8, imported_path, current_path)) return true;

    for (extensions) |extension| {
        const with_extension = try std.mem.concat(allocator, u8, &.{ imported_path, extension });
        defer allocator.free(with_extension);
        if (std.mem.eql(u8, with_extension, current_path)) return true;

        const index_name = try std.mem.concat(allocator, u8, &.{ "index", extension });
        defer allocator.free(index_name);
        const index_path = try std.fs.path.join(allocator, &.{ imported_path, index_name });
        defer allocator.free(index_path);
        if (std.mem.eql(u8, index_path, current_path)) return true;
    }

    return false;
}
