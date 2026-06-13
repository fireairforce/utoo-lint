const std = @import("std");
const parser = @import("parser");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const extensions = [_][]const u8{
    ".ts",
    ".cts",
    ".mts",
    ".tsx",
    ".js",
    ".jsx",
    ".mjs",
    ".cjs",
};

const max_source_size = 1024 * 1024;
const max_reexport_depth = 8;

pub const ExportMap = struct {
    has_default: bool = false,
};

pub fn resolveRelativeModule(
    allocator: Allocator,
    io: std.Io,
    file_path: []const u8,
    source: []const u8,
) Allocator.Error!?[]const u8 {
    if (!isRelativeImport(source)) return null;

    const directory = std.fs.path.dirname(file_path) orelse ".";
    const imported_path = try std.fs.path.resolve(allocator, &.{ directory, source });
    errdefer allocator.free(imported_path);

    if (isFile(io, imported_path)) return imported_path;

    for (extensions) |extension| {
        const with_extension = try std.mem.concat(allocator, u8, &.{ imported_path, extension });
        if (isFile(io, with_extension)) {
            allocator.free(imported_path);
            return with_extension;
        }
        allocator.free(with_extension);
    }

    for (extensions) |extension| {
        const index_name = try std.mem.concat(allocator, u8, &.{ "index", extension });
        defer allocator.free(index_name);

        const index_path = try std.fs.path.join(allocator, &.{ imported_path, index_name });
        if (isFile(io, index_path)) {
            allocator.free(imported_path);
            return index_path;
        }
        allocator.free(index_path);
    }

    allocator.free(imported_path);
    return null;
}

pub fn readExportMap(
    allocator: Allocator,
    io: std.Io,
    path: []const u8,
) Allocator.Error!?ExportMap {
    var visited = std.StringHashMap(void).init(allocator);
    defer {
        var iter = visited.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        visited.deinit();
    }

    return readExportMapInner(allocator, io, path, &visited, 0);
}

fn readExportMapInner(
    allocator: Allocator,
    io: std.Io,
    path: []const u8,
    visited: *std.StringHashMap(void),
    depth: usize,
) Allocator.Error!?ExportMap {
    if (depth > max_reexport_depth) return null;
    if (visited.contains(path)) return null;

    const owned_path = try allocator.dupe(u8, path);
    errdefer allocator.free(owned_path);
    try visited.put(owned_path, {});

    const source = readFile(allocator, io, path) orelse return null;
    defer allocator.free(source);

    var tree = parser.parse(allocator, source, .{
        .source_type = ast.SourceType.fromPath(path),
        .lang = ast.Lang.fromPath(path),
    }) catch return null;
    defer tree.deinit();
    if (tree.hasErrors()) return null;

    const program = switch (tree.data(tree.root)) {
        .program => |program| program,
        else => return null,
    };

    var map = ExportMap{};
    for (tree.extra(program.body)) |statement_index| {
        switch (tree.data(statement_index)) {
            .export_default_declaration => map.has_default = true,
            .export_named_declaration => |declaration| {
                if (declaration.export_kind == .type) continue;
                if (hasDefaultSpecifier(&tree, declaration)) {
                    if (exportNamedSource(&tree, declaration)) |reexport_source| {
                        if (try reexportHasDefault(allocator, io, path, reexport_source, visited, depth)) {
                            map.has_default = true;
                        }
                    } else {
                        map.has_default = true;
                    }
                }
            },
            .export_all_declaration => |declaration| {
                if (declaration.export_kind == .type) continue;
                if (declaration.exported != .null) {
                    if (moduleExportName(&tree, declaration.exported)) |name| {
                        if (std.mem.eql(u8, name, "default")) {
                            map.has_default = true;
                        }
                    }
                }
            },
            else => {},
        }
    }

    return map;
}

fn reexportHasDefault(
    allocator: Allocator,
    io: std.Io,
    path: []const u8,
    source: []const u8,
    visited: *std.StringHashMap(void),
    depth: usize,
) Allocator.Error!bool {
    const resolved = try resolveRelativeModule(allocator, io, path, source) orelse return false;
    defer allocator.free(resolved);

    const map = try readExportMapInner(allocator, io, resolved, visited, depth + 1) orelse return false;
    return map.has_default;
}

fn hasDefaultSpecifier(tree: *const ast.Tree, declaration: ast.ExportNamedDeclaration) bool {
    for (tree.extra(declaration.specifiers)) |specifier_index| {
        const specifier = switch (tree.data(specifier_index)) {
            .export_specifier => |specifier| specifier,
            else => continue,
        };
        if (specifier.export_kind == .type) continue;
        const exported = moduleExportName(tree, specifier.exported) orelse continue;
        if (std.mem.eql(u8, exported, "default")) return true;
    }
    return false;
}

fn exportNamedSource(tree: *const ast.Tree, declaration: ast.ExportNamedDeclaration) ?[]const u8 {
    if (declaration.source == .null) return null;
    return switch (tree.data(declaration.source)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn moduleExportName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

pub fn importSource(tree: *const ast.Tree, declaration: ast.ImportDeclaration) ?[]const u8 {
    return switch (tree.data(declaration.source)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

pub fn isRelativeImport(source: []const u8) bool {
    return std.mem.startsWith(u8, source, "./") or
        std.mem.startsWith(u8, source, "../") or
        std.mem.eql(u8, source, ".") or
        std.mem.eql(u8, source, "..");
}

fn readFile(allocator: Allocator, io: std.Io, path: []const u8) ?[]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_source_size)) catch null;
}

fn isFile(io: std.Io, path: []const u8) bool {
    const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch return false;
    file.close(io);
    return true;
}
