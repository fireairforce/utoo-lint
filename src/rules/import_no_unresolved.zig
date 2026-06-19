const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const export_map = @import("import_export_map.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "import/no-unresolved";

const max_package_json_size = 128 * 1024;

const resolve_extensions = [_][]const u8{
    "",
    ".js",
    ".jsx",
    ".json",
    ".ts",
    ".tsx",
    ".d.ts",
    ".mjs",
    ".cjs",
    ".mts",
    ".cts",
};

pub const Options = struct {
    amd: bool = false,
    commonjs: bool = false,
    ignore: core.ImportNoUnresolvedIgnorePatterns = .{},
};

pub fn run(
    allocator: Allocator,
    io: std.Io,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    file_path: []const u8,
    options: Options,
) Allocator.Error!void {
    const program = switch (tree.data(tree.root)) {
        .program => |program| program,
        else => return,
    };

    for (tree.extra(program.body)) |statement_index| {
        switch (tree.data(statement_index)) {
            .import_declaration => |declaration| {
                if (declaration.import_kind == .type) continue;
                try checkSourceNode(allocator, io, diagnostics, tree, file_path, declaration.source, options);
            },
            .export_named_declaration => |declaration| {
                if (declaration.export_kind == .type or declaration.source == .null) continue;
                try checkSourceNode(allocator, io, diagnostics, tree, file_path, declaration.source, options);
            },
            .export_all_declaration => |declaration| {
                if (declaration.export_kind == .type) continue;
                try checkSourceNode(allocator, io, diagnostics, tree, file_path, declaration.source, options);
            },
            else => {},
        }
    }

    var visitor = DynamicImportVisitor{
        .allocator = allocator,
        .io = io,
        .diagnostics = diagnostics,
        .file_path = file_path,
        .options = options,
    };
    try traverser.basic.traverse(DynamicImportVisitor, tree, &visitor);
}

const DynamicImportVisitor = struct {
    allocator: Allocator,
    io: std.Io,
    diagnostics: *core.DiagnosticList,
    file_path: []const u8,
    options: Options,

    pub fn enter_import_expression(
        self: *DynamicImportVisitor,
        expression: ast.ImportExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try checkSourceNode(self.allocator, self.io, self.diagnostics, ctx.tree, self.file_path, expression.source, self.options);
        return .proceed;
    }

    pub fn enter_call_expression(
        self: *DynamicImportVisitor,
        call: ast.CallExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const arguments = ctx.tree.extra(call.arguments);
        if (self.options.commonjs and isRequireCall(ctx.tree, call) and arguments.len == 1) {
            try checkSourceNode(self.allocator, self.io, self.diagnostics, ctx.tree, self.file_path, arguments[0], self.options);
        }
        if (self.options.amd and isAmdCall(ctx.tree, call)) {
            try self.checkAmdDependencies(ctx.tree, arguments);
        }
        return .proceed;
    }

    fn checkAmdDependencies(
        self: *DynamicImportVisitor,
        tree: *const ast.Tree,
        arguments: []const ast.NodeIndex,
    ) Allocator.Error!void {
        if (arguments.len == 0) return;
        const dependencies = switch (tree.data(unwrapTransparent(tree, arguments[0]))) {
            .array_expression => |array| array,
            else => return,
        };
        for (tree.extra(dependencies.elements)) |element| {
            if (element == .null) continue;
            try checkSourceNode(self.allocator, self.io, self.diagnostics, tree, self.file_path, element, self.options);
        }
    }
};

fn checkSourceNode(
    allocator: Allocator,
    io: std.Io,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    file_path: []const u8,
    source_node: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    const source = stringLiteralValue(tree, source_node) orelse return;
    if (shouldIgnore(source, options.ignore)) return;
    if (try resolves(allocator, io, file_path, source)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(source_node),
        "Unable to resolve path to module '{s}'.",
        .{source},
    );
}

fn resolves(
    allocator: Allocator,
    io: std.Io,
    file_path: []const u8,
    source: []const u8,
) Allocator.Error!bool {
    if (source.len == 0) return false;
    if (isBuiltinModule(source)) return true;

    if (export_map.isRelativeImport(source)) {
        const resolved = try resolveRelativeModule(allocator, io, file_path, source) orelse return false;
        allocator.free(resolved);
        return true;
    }

    if (std.fs.path.isAbsolute(source)) {
        const resolved = try resolveAsFileOrDirectory(allocator, io, source) orelse return false;
        allocator.free(resolved);
        return true;
    }

    return try resolveNodeModule(allocator, io, file_path, source);
}

fn resolveRelativeModule(
    allocator: Allocator,
    io: std.Io,
    file_path: []const u8,
    source: []const u8,
) Allocator.Error!?[]const u8 {
    const directory = std.fs.path.dirname(file_path) orelse ".";
    const imported_path = try std.fs.path.resolve(allocator, &.{ directory, source });
    defer allocator.free(imported_path);
    return resolveAsFileOrDirectory(allocator, io, imported_path);
}

fn resolveNodeModule(
    allocator: Allocator,
    io: std.Io,
    file_path: []const u8,
    source: []const u8,
) Allocator.Error!bool {
    const package = packageName(source) orelse return false;
    const subpath = source[package.len..];

    var current = try std.fs.path.resolve(allocator, &.{std.fs.path.dirname(file_path) orelse "."});
    defer allocator.free(current);

    while (true) {
        const package_dir = try std.fs.path.join(allocator, &.{ current, "node_modules", package });
        if (isDirectory(io, package_dir)) {
            if (subpath.len > 0) {
                const without_slash = if (subpath[0] == '/') subpath[1..] else subpath;
                const target = try std.fs.path.join(allocator, &.{ package_dir, without_slash });
                allocator.free(package_dir);
                defer allocator.free(target);
                const resolved = try resolveAsFileOrDirectory(allocator, io, target) orelse return false;
                allocator.free(resolved);
                return true;
            }

            const resolved = try resolvePackageDirectory(allocator, io, package_dir);
            allocator.free(package_dir);
            if (resolved) |path| {
                allocator.free(path);
                return true;
            }
            return false;
        }
        allocator.free(package_dir);

        const parent = std.fs.path.dirname(current) orelse return false;
        if (std.mem.eql(u8, parent, current)) return false;
        const next = try allocator.dupe(u8, parent);
        allocator.free(current);
        current = next;
    }
}

fn resolveAsFileOrDirectory(
    allocator: Allocator,
    io: std.Io,
    path: []const u8,
) Allocator.Error!?[]const u8 {
    if (isFile(io, path)) {
        const owned = try allocator.dupe(u8, path);
        return owned;
    }

    for (resolve_extensions) |extension| {
        if (extension.len == 0) continue;
        const with_extension = try std.mem.concat(allocator, u8, &.{ path, extension });
        if (isFile(io, with_extension)) return with_extension;
        allocator.free(with_extension);
    }

    if (!isDirectory(io, path)) return null;
    if (try resolvePackageDirectory(allocator, io, path)) |resolved| return resolved;

    for (resolve_extensions) |extension| {
        if (extension.len == 0) continue;
        const index_name = try std.mem.concat(allocator, u8, &.{ "index", extension });
        defer allocator.free(index_name);
        const index_path = try std.fs.path.join(allocator, &.{ path, index_name });
        if (isFile(io, index_path)) return index_path;
        allocator.free(index_path);
    }

    return null;
}

fn resolvePackageDirectory(
    allocator: Allocator,
    io: std.Io,
    package_dir: []const u8,
) Allocator.Error!?[]const u8 {
    const package_json_path = try std.fs.path.join(allocator, &.{ package_dir, "package.json" });
    defer allocator.free(package_json_path);

    if (readFile(allocator, io, package_json_path)) |source| {
        defer allocator.free(source);
        if (packageMain(allocator, source)) |main_path| {
            defer allocator.free(main_path);
            if (main_path.len > 0) {
                const candidate = try std.fs.path.join(allocator, &.{ package_dir, main_path });
                defer allocator.free(candidate);
                if (try resolveAsFileOrDirectory(allocator, io, candidate)) |resolved| return resolved;
            }
        }
    }

    for (resolve_extensions) |extension| {
        if (extension.len == 0) continue;
        const index_name = try std.mem.concat(allocator, u8, &.{ "index", extension });
        defer allocator.free(index_name);
        const index_path = try std.fs.path.join(allocator, &.{ package_dir, index_name });
        if (isFile(io, index_path)) return index_path;
        allocator.free(index_path);
    }

    return null;
}

fn packageMain(allocator: Allocator, source: []const u8) ?[]const u8 {
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{}) catch return null;
    defer parsed.deinit();

    const root = switch (parsed.value) {
        .object => |object| object,
        else => return null,
    };

    const fields = [_][]const u8{ "module", "main" };
    for (fields) |field| {
        const value = root.get(field) orelse continue;
        const string = switch (value) {
            .string => |string| string,
            else => continue,
        };
        return allocator.dupe(u8, string) catch null;
    }
    return null;
}

fn readFile(allocator: Allocator, io: std.Io, path: []const u8) ?[]u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_package_json_size)) catch null;
}

fn isFile(io: std.Io, path: []const u8) bool {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return stat.kind == .file;
}

fn isDirectory(io: std.Io, path: []const u8) bool {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return stat.kind == .directory;
}

fn packageName(source: []const u8) ?[]const u8 {
    if (source.len == 0 or source[0] == '/' or source[0] == '.') return null;
    if (source[0] != '@') {
        const slash = std.mem.indexOfScalar(u8, source, '/') orelse source.len;
        return source[0..slash];
    }

    const first_slash = std.mem.indexOfScalarPos(u8, source, 1, '/') orelse return null;
    const second_slash = std.mem.indexOfScalarPos(u8, source, first_slash + 1, '/') orelse source.len;
    return source[0..second_slash];
}

fn shouldIgnore(source: []const u8, ignore: core.ImportNoUnresolvedIgnorePatterns) bool {
    if (std.mem.startsWith(u8, source, "smallfish:") or
        std.mem.startsWith(u8, source, "minifish:")) return true;

    for (0..ignore.count) |index| {
        if (matchesIgnorePattern(ignore.at(index), source)) return true;
    }
    return false;
}

fn matchesIgnorePattern(pattern: []const u8, source: []const u8) bool {
    if (pattern.len == 0) return false;
    const anchored_start = pattern[0] == '^';
    const anchored_end = hasUnescapedTrailingDollar(pattern);
    const start: usize = if (anchored_start) 1 else 0;
    const end: usize = if (anchored_end) pattern.len - 1 else pattern.len;
    const body = pattern[start..end];

    if (anchored_start) {
        return matchPatternAt(body, 0, source, 0, anchored_end);
    }

    for (0..source.len + 1) |source_index| {
        if (matchPatternAt(body, 0, source, source_index, anchored_end)) return true;
    }
    return false;
}

fn hasUnescapedTrailingDollar(pattern: []const u8) bool {
    if (pattern.len == 0 or pattern[pattern.len - 1] != '$') return false;
    var slash_count: usize = 0;
    var index = pattern.len - 1;
    while (index > 0) {
        index -= 1;
        if (pattern[index] != '\\') break;
        slash_count += 1;
    }
    return slash_count % 2 == 0;
}

fn matchPatternAt(pattern: []const u8, pattern_index: usize, source: []const u8, source_index: usize, anchored_end: bool) bool {
    if (pattern_index >= pattern.len) return !anchored_end or source_index == source.len;

    const token = readPatternToken(pattern, pattern_index);
    const next_index = token.next_index;
    if (next_index < pattern.len and pattern[next_index] == '*') {
        var end_index = source_index;
        while (end_index < source.len and token.matches(source[end_index])) {
            end_index += 1;
        }
        while (true) {
            if (matchPatternAt(pattern, next_index + 1, source, end_index, anchored_end)) return true;
            if (end_index == source_index) break;
            end_index -= 1;
        }
        return false;
    }

    if (source_index >= source.len or !token.matches(source[source_index])) return false;
    return matchPatternAt(pattern, next_index, source, source_index + 1, anchored_end);
}

const PatternToken = struct {
    kind: enum { any, literal },
    literal: u8 = 0,
    next_index: usize,

    fn matches(self: PatternToken, value: u8) bool {
        return switch (self.kind) {
            .any => true,
            .literal => self.literal == value,
        };
    }
};

fn readPatternToken(pattern: []const u8, index: usize) PatternToken {
    if (pattern[index] == '\\' and index + 1 < pattern.len) {
        return .{
            .kind = .literal,
            .literal = pattern[index + 1],
            .next_index = index + 2,
        };
    }
    if (pattern[index] == '.') {
        return .{
            .kind = .any,
            .next_index = index + 1,
        };
    }
    return .{
        .kind = .literal,
        .literal = pattern[index],
        .next_index = index + 1,
    };
}

fn isRequireCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    return isIdentifierReferenceNamed(tree, unwrapTransparent(tree, call.callee), "require");
}

fn isAmdCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const callee = unwrapTransparent(tree, call.callee);
    return isIdentifierReferenceNamed(tree, callee, "define") or
        isIdentifierReferenceNamed(tree, callee, "require");
}

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    const name = switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => return false,
    };
    return std.mem.eql(u8, name, expected);
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;
    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |chain| current = chain.expression,
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            else => return current,
        }
    }
    return current;
}

fn stringLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn isBuiltinModule(source: []const u8) bool {
    const name = if (std.mem.startsWith(u8, source, "node:")) source["node:".len..] else source;
    return builtin_modules.has(name);
}

const builtin_modules = std.StaticStringMap(void).initComptime(.{
    .{ "assert", {} },
    .{ "async_hooks", {} },
    .{ "buffer", {} },
    .{ "child_process", {} },
    .{ "cluster", {} },
    .{ "console", {} },
    .{ "constants", {} },
    .{ "crypto", {} },
    .{ "dgram", {} },
    .{ "diagnostics_channel", {} },
    .{ "dns", {} },
    .{ "domain", {} },
    .{ "events", {} },
    .{ "fs", {} },
    .{ "http", {} },
    .{ "http2", {} },
    .{ "https", {} },
    .{ "inspector", {} },
    .{ "module", {} },
    .{ "net", {} },
    .{ "os", {} },
    .{ "path", {} },
    .{ "perf_hooks", {} },
    .{ "process", {} },
    .{ "punycode", {} },
    .{ "querystring", {} },
    .{ "readline", {} },
    .{ "repl", {} },
    .{ "stream", {} },
    .{ "string_decoder", {} },
    .{ "sys", {} },
    .{ "timers", {} },
    .{ "tls", {} },
    .{ "tty", {} },
    .{ "url", {} },
    .{ "util", {} },
    .{ "v8", {} },
    .{ "vm", {} },
    .{ "wasi", {} },
    .{ "worker_threads", {} },
    .{ "zlib", {} },
});
