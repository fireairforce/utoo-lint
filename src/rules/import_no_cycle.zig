const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const export_map = @import("import_export_map.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "import/no-cycle";

const max_source_size = 1024 * 1024;
const max_depth = 1024;

const Dependency = struct {
    source: []const u8,
    resolved: []const u8,
    line: usize,

    fn deinit(self: Dependency, allocator: Allocator) void {
        allocator.free(self.source);
        allocator.free(self.resolved);
    }
};

const RouteStep = struct {
    source: []const u8,
    line: usize,

    fn deinit(self: RouteStep, allocator: Allocator) void {
        allocator.free(self.source);
    }
};

pub fn run(
    allocator: Allocator,
    io: std.Io,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    file_path: []const u8,
) Allocator.Error!void {
    const normalized_file_path = try std.fs.path.resolve(allocator, &.{file_path});
    defer allocator.free(normalized_file_path);

    var dependencies = try collectDependencies(allocator, io, tree, normalized_file_path);
    defer deinitDependencies(allocator, &dependencies);

    for (dependencies.items) |dependency| {
        if (std.mem.eql(u8, dependency.resolved, normalized_file_path)) continue;

        var visited = std.StringHashMap(void).init(allocator);
        defer freeVisited(allocator, &visited);

        var route: std.ArrayList(RouteStep) = .empty;
        defer deinitRoute(allocator, &route);

        if (try hasCycle(allocator, io, dependency.resolved, normalized_file_path, &visited, &route, 0)) {
            try reportCycle(allocator, diagnostics, tree, dependency.line, dependency.source, &route);
        }
    }
}

fn hasCycle(
    allocator: Allocator,
    io: std.Io,
    path: []const u8,
    target: []const u8,
    visited: *std.StringHashMap(void),
    route: *std.ArrayList(RouteStep),
    depth: usize,
) Allocator.Error!bool {
    if (depth >= max_depth) return false;
    if (visited.contains(path)) return false;

    const owned_path = try allocator.dupe(u8, path);
    errdefer allocator.free(owned_path);
    try visited.put(owned_path, {});

    var dependencies = try collectFileDependencies(allocator, io, path);
    defer deinitDependencies(allocator, &dependencies);

    for (dependencies.items) |dependency| {
        if (std.mem.eql(u8, dependency.resolved, target)) {
            return true;
        }
    }

    for (dependencies.items) |dependency| {
        const source = try allocator.dupe(u8, dependency.source);
        errdefer allocator.free(source);
        try route.append(allocator, .{
            .source = source,
            .line = dependency.line,
        });

        if (try hasCycle(allocator, io, dependency.resolved, target, visited, route, depth + 1)) {
            return true;
        }

        const removed = route.pop() orelse unreachable;
        removed.deinit(allocator);
    }

    return false;
}

fn reportCycle(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    line: usize,
    source: []const u8,
    route: *const std.ArrayList(RouteStep),
) Allocator.Error!void {
    const node = findDependencyNode(tree, line, source) orelse tree.root;

    if (route.items.len == 0) {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .@"error",
            id,
            "Dependency cycle detected.",
            tree.span(node),
        );
        return;
    }

    const route_text = try formatRoute(allocator, route);
    defer allocator.free(route_text);

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(node),
        "Dependency cycle via {s}",
        .{route_text},
    );
}

fn formatRoute(allocator: Allocator, route: *const std.ArrayList(RouteStep)) Allocator.Error![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    for (route.items, 0..) |step, index| {
        if (index > 0) try out.appendSlice(allocator, "=>");
        const part = try std.fmt.allocPrint(allocator, "{s}:{d}", .{ step.source, step.line });
        defer allocator.free(part);
        try out.appendSlice(allocator, part);
    }

    return out.toOwnedSlice(allocator);
}

fn findDependencyNode(tree: *const ast.Tree, line: usize, source: []const u8) ?ast.NodeIndex {
    const program = switch (tree.data(tree.root)) {
        .program => |program| program,
        else => return null,
    };

    for (tree.extra(program.body)) |statement_index| {
        switch (tree.data(statement_index)) {
            .import_declaration => |declaration| {
                if (declaration.import_kind == .type) continue;
                if (declaration.specifiers.len == 0) continue;
                if (isOnlyTypeImport(tree, declaration)) continue;
                const import_source = export_map.importSource(tree, declaration) orelse continue;
                if (std.mem.eql(u8, import_source, source)) return statement_index;
            },
            .export_named_declaration => |declaration| {
                if (declaration.export_kind == .type) continue;
                const export_source = exportNamedSource(tree, declaration) orelse continue;
                if (std.mem.eql(u8, export_source, source)) return statement_index;
            },
            .export_all_declaration => |declaration| {
                if (declaration.export_kind == .type) continue;
                const export_source = exportAllSource(tree, declaration) orelse continue;
                if (std.mem.eql(u8, export_source, source)) return statement_index;
            },
            else => {},
        }
    }

    _ = line;
    return null;
}

fn collectFileDependencies(
    allocator: Allocator,
    io: std.Io,
    path: []const u8,
) Allocator.Error!std.ArrayList(Dependency) {
    const source = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_source_size)) catch return .empty;
    defer allocator.free(source);

    var tree = parser.parse(allocator, source, .{
        .source_type = ast.SourceType.fromPath(path),
        .lang = ast.Lang.fromPath(path),
    }) catch return .empty;
    defer tree.deinit();
    if (tree.hasErrors()) return .empty;

    return collectDependenciesFromSource(allocator, io, &tree, path, source);
}

fn collectDependencies(
    allocator: Allocator,
    io: std.Io,
    tree: *const ast.Tree,
    path: []const u8,
) Allocator.Error!std.ArrayList(Dependency) {
    return collectDependenciesFromSource(allocator, io, tree, path, "");
}

fn collectDependenciesFromSource(
    allocator: Allocator,
    io: std.Io,
    tree: *const ast.Tree,
    path: []const u8,
    source_text: []const u8,
) Allocator.Error!std.ArrayList(Dependency) {
    var dependencies: std.ArrayList(Dependency) = .empty;
    errdefer deinitDependencies(allocator, &dependencies);

    const program = switch (tree.data(tree.root)) {
        .program => |program| program,
        else => return dependencies,
    };

    for (tree.extra(program.body)) |statement_index| {
        switch (tree.data(statement_index)) {
            .import_declaration => |declaration| {
                if (declaration.import_kind == .type) continue;
                if (declaration.specifiers.len == 0) continue;
                if (isOnlyTypeImport(tree, declaration)) continue;
                const source = export_map.importSource(tree, declaration) orelse continue;
                try appendDependency(allocator, io, &dependencies, tree, source_text, path, source, statement_index);
            },
            .export_named_declaration => |declaration| {
                if (declaration.export_kind == .type) continue;
                const source = exportNamedSource(tree, declaration) orelse continue;
                try appendDependency(allocator, io, &dependencies, tree, source_text, path, source, statement_index);
            },
            .export_all_declaration => |declaration| {
                if (declaration.export_kind == .type) continue;
                const source = exportAllSource(tree, declaration) orelse continue;
                try appendDependency(allocator, io, &dependencies, tree, source_text, path, source, statement_index);
            },
            else => {},
        }
    }

    return dependencies;
}

fn appendDependency(
    allocator: Allocator,
    io: std.Io,
    dependencies: *std.ArrayList(Dependency),
    tree: *const ast.Tree,
    source_text: []const u8,
    path: []const u8,
    source: []const u8,
    statement_index: ast.NodeIndex,
) Allocator.Error!void {
    const resolved = try export_map.resolveRelativeModule(allocator, io, path, source) orelse return;
    errdefer allocator.free(resolved);
    const owned_source = try allocator.dupe(u8, source);
    errdefer allocator.free(owned_source);

    try dependencies.append(allocator, .{
        .source = owned_source,
        .resolved = resolved,
        .line = lineForOffset(source_text, tree.span(statement_index).start),
    });
}

fn isOnlyTypeImport(tree: *const ast.Tree, declaration: ast.ImportDeclaration) bool {
    if (declaration.specifiers.len == 0) return false;
    for (tree.extra(declaration.specifiers)) |specifier_index| {
        switch (tree.data(specifier_index)) {
            .import_specifier => |specifier| {
                if (specifier.import_kind != .type) return false;
            },
            else => return false,
        }
    }
    return true;
}

fn lineForOffset(source: []const u8, offset: u32) usize {
    const end = @min(@as(usize, @intCast(offset)), source.len);
    var line: usize = 1;
    for (source[0..end]) |char| {
        if (char == '\n') line += 1;
    }
    return line;
}

fn deinitDependencies(allocator: Allocator, dependencies: *std.ArrayList(Dependency)) void {
    for (dependencies.items) |dependency| dependency.deinit(allocator);
    dependencies.deinit(allocator);
}

fn deinitRoute(allocator: Allocator, route: *std.ArrayList(RouteStep)) void {
    for (route.items) |step| step.deinit(allocator);
    route.deinit(allocator);
}

fn freeVisited(allocator: Allocator, visited: *std.StringHashMap(void)) void {
    var iter = visited.iterator();
    while (iter.next()) |entry| {
        allocator.free(entry.key_ptr.*);
    }
    visited.deinit();
}

fn exportNamedSource(tree: *const ast.Tree, declaration: ast.ExportNamedDeclaration) ?[]const u8 {
    if (declaration.source == .null) return null;
    return switch (tree.data(declaration.source)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn exportAllSource(tree: *const ast.Tree, declaration: ast.ExportAllDeclaration) ?[]const u8 {
    if (declaration.source == .null) return null;
    return switch (tree.data(declaration.source)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}
