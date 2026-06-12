const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-duplicate-imports";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    program: ast.Program,
) Allocator.Error!void {
    var seen_sources: std.ArrayList([]const u8) = .empty;
    defer seen_sources.deinit(allocator);

    for (tree.extra(program.body)) |statement_index| {
        const declaration = switch (tree.data(statement_index)) {
            .import_declaration => |declaration| declaration,
            else => continue,
        };
        const source = importSource(tree, declaration) orelse continue;

        if (contains(seen_sources.items, source)) {
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .warning,
                id,
                tree.span(statement_index),
                "Duplicate import from \"{s}\".",
                .{source},
            );
            continue;
        }

        try seen_sources.append(allocator, source);
    }
}

fn importSource(tree: *const ast.Tree, declaration: ast.ImportDeclaration) ?[]const u8 {
    return switch (tree.data(declaration.source)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn contains(items: []const []const u8, source: []const u8) bool {
    for (items) |item| {
        if (std.mem.eql(u8, item, source)) return true;
    }
    return false;
}
