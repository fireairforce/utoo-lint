const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/ant/no-import-files-from-pages-in-common";

pub fn checkImportDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.ImportDeclaration,
    index: ast.NodeIndex,
    file_path: []const u8,
) Allocator.Error!void {
    if (std.mem.indexOf(u8, file_path, "src/common") == null) return;

    const source = importSource(tree, declaration) orelse return;
    if (std.mem.indexOf(u8, source, "appfw") == null or
        std.mem.indexOf(u8, source, "page-") == null)
    {
        return;
    }

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "don't import things from src/pages/ while you're in src/common: reading `{s}` now.",
        .{source},
    );
}

fn importSource(tree: *const ast.Tree, declaration: ast.ImportDeclaration) ?[]const u8 {
    return switch (tree.data(declaration.source)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}
