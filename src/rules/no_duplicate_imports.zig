const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-duplicate-imports";

pub const Options = struct {
    allow_separate_type_imports: bool = false,
};

const ImportKind = enum {
    named_only,
    namespace_only,
    other,
};

const SeenImport = struct {
    source: []const u8,
    kind: ImportKind,
    import_kind: ast.ImportOrExportKind,
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
        const kind = importKind(tree, declaration);

        if (hasDuplicate(seen.items, source, kind, declaration.import_kind, options)) {
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

        try seen.append(allocator, .{
            .source = source,
            .kind = kind,
            .import_kind = declaration.import_kind,
        });
    }
}

fn importSource(tree: *const ast.Tree, declaration: ast.ImportDeclaration) ?[]const u8 {
    return switch (tree.data(declaration.source)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn importKind(tree: *const ast.Tree, declaration: ast.ImportDeclaration) ImportKind {
    const specifiers = tree.extra(declaration.specifiers);
    if (specifiers.len == 1 and tree.data(specifiers[0]) == .import_namespace_specifier) return .namespace_only;
    if (specifiers.len == 0) return .other;

    for (specifiers) |specifier| {
        if (tree.data(specifier) != .import_specifier) return .other;
    }
    return .named_only;
}

fn hasDuplicate(
    items: []const SeenImport,
    source: []const u8,
    kind: ImportKind,
    import_kind: ast.ImportOrExportKind,
    options: Options,
) bool {
    for (items) |item| {
        if (!std.mem.eql(u8, item.source, source)) continue;
        if (options.allow_separate_type_imports and canSeparateTypeImports(item.import_kind, import_kind)) continue;
        if (canCoexist(item.kind, kind)) continue;
        return true;
    }
    return false;
}

fn canCoexist(a: ImportKind, b: ImportKind) bool {
    return (a == .namespace_only and b == .named_only) or
        (a == .named_only and b == .namespace_only);
}

fn canSeparateTypeImports(a: ast.ImportOrExportKind, b: ast.ImportOrExportKind) bool {
    return (a == .type and b == .value) or
        (a == .value and b == .type);
}
