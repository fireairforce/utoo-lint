const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "import/no-duplicates";

pub const Options = struct {
    consider_query_string: bool = false,
};

const SeenImport = struct {
    source: []const u8,
    key: []const u8,
    source_node: ast.NodeIndex,
    reported: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    program: ast.Program,
) Allocator.Error!void {
    try checkWithOptions(allocator, diagnostics, tree, program, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    program: ast.Program,
    options: Options,
) Allocator.Error!void {
    var seen: std.ArrayList(SeenImport) = .empty;
    defer seen.deinit(allocator);

    for (tree.extra(program.body)) |statement_index| {
        const declaration = switch (tree.data(statement_index)) {
            .import_declaration => |declaration| declaration,
            else => continue,
        };
        const source = importSource(tree, declaration) orelse continue;
        const key = importKey(source, options);

        if (findSeen(seen.items, key)) |seen_index| {
            if (!seen.items[seen_index].reported) {
                try addDiagnostic(allocator, diagnostics, tree, seen.items[seen_index].source_node, seen.items[seen_index].source);
                seen.items[seen_index].reported = true;
            }
            try addDiagnostic(allocator, diagnostics, tree, declaration.source, source);
            continue;
        }

        try seen.append(allocator, .{
            .source = source,
            .key = key,
            .source_node = declaration.source,
        });
    }
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    source: []const u8,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "'{s}' imported multiple times.",
        .{source},
    );
}

fn importSource(tree: *const ast.Tree, declaration: ast.ImportDeclaration) ?[]const u8 {
    return switch (tree.data(declaration.source)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn importKey(source: []const u8, options: Options) []const u8 {
    if (options.consider_query_string) return source;
    const query_index = std.mem.indexOfScalar(u8, source, '?') orelse return source;
    return source[0..query_index];
}

fn findSeen(items: []const SeenImport, key: []const u8) ?usize {
    for (items, 0..) |item, i| {
        if (std.mem.eql(u8, item.key, key)) return i;
    }
    return null;
}
