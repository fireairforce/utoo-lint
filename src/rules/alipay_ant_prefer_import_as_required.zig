const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/ant/prefer-import-as-required";

const default_check_deps = [_][]const u8{
    "lodash-es",
    "@example/content-components",
    "@example/widget-components",
    "@example/content-utils",
    "@example/widget-utils",
    "@example/shared-utils",
    "@example/shared-hooks",
    "appfw:stdlib/lodash",
    "@example/stdlib",
};

pub fn checkImportDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.ImportDeclaration,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const source = importSource(tree, declaration) orelse return;
    if (!isDefaultOrNamespaceImport(tree, declaration)) return;
    if (!isCheckedDependency(source)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "使用按需引入以减小构建包体积: {s}.",
        .{source},
    );
}

fn isDefaultOrNamespaceImport(tree: *const ast.Tree, declaration: ast.ImportDeclaration) bool {
    for (tree.extra(declaration.specifiers)) |specifier| {
        switch (tree.data(specifier)) {
            .import_default_specifier, .import_namespace_specifier => return true,
            else => {},
        }
    }
    return false;
}

fn isCheckedDependency(source: []const u8) bool {
    for (default_check_deps) |dependency| {
        if (std.mem.eql(u8, source, dependency)) return true;
    }
    return false;
}

fn importSource(tree: *const ast.Tree, declaration: ast.ImportDeclaration) ?[]const u8 {
    return switch (tree.data(declaration.source)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}
