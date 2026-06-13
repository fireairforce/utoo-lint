const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "import/no-duplicates";

const SeenImport = struct {
    source: []const u8,
    source_node: ast.NodeIndex,
    reported: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    program: ast.Program,
) Allocator.Error!void {
    var seen: std.ArrayList(SeenImport) = .empty;
    defer seen.deinit(allocator);

    for (tree.extra(program.body)) |statement_index| {
        const declaration = switch (tree.data(statement_index)) {
            .import_declaration => |declaration| declaration,
            else => continue,
        };
        const source = importSource(tree, declaration) orelse continue;

        if (findSeen(seen.items, source)) |seen_index| {
            if (!seen.items[seen_index].reported) {
                try addDiagnostic(allocator, diagnostics, tree, seen.items[seen_index].source_node, source);
                seen.items[seen_index].reported = true;
            }
            try addDiagnostic(allocator, diagnostics, tree, declaration.source, source);
            continue;
        }

        try seen.append(allocator, .{ .source = source, .source_node = declaration.source });
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

fn findSeen(items: []const SeenImport, source: []const u8) ?usize {
    for (items, 0..) |item, i| {
        if (std.mem.eql(u8, item.source, source)) return i;
    }
    return null;
}
