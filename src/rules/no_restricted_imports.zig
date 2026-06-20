const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-restricted-imports";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    program: ast.Program,
    restrictions: core.NoRestrictedImports,
) Allocator.Error!void {
    if (restrictions.count == 0) return;

    for (tree.extra(program.body)) |statement_index| {
        switch (tree.data(statement_index)) {
            .import_declaration => |declaration| try checkImportDeclaration(
                allocator,
                diagnostics,
                tree,
                declaration,
                restrictions,
            ),
            .export_named_declaration => |declaration| try checkExportNamedDeclaration(
                allocator,
                diagnostics,
                tree,
                declaration,
                restrictions,
            ),
            .export_all_declaration => |declaration| try checkExportAllDeclaration(
                allocator,
                diagnostics,
                tree,
                declaration,
                restrictions,
            ),
            else => {},
        }
    }
}

fn checkImportDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.ImportDeclaration,
    restrictions: core.NoRestrictedImports,
) Allocator.Error!void {
    const source = stringLiteralValue(tree, declaration.source) orelse return;

    for (0..restrictions.count) |index| {
        const entry = restrictions.at(index);
        if (!entryMatches(entry, source)) continue;

        if (entry.import_names.count == 0 and entry.allow_import_names.count == 0) {
            if (declaration.import_kind == .type and entry.allow_type_imports) continue;
            try reportModule(allocator, diagnostics, tree, declaration.source, source, entry);
            continue;
        }

        for (tree.extra(declaration.specifiers)) |specifier_index| {
            switch (tree.data(specifier_index)) {
                .import_default_specifier => try checkImportName(
                    allocator,
                    diagnostics,
                    tree,
                    specifier_index,
                    source,
                    "default",
                    declaration.import_kind,
                    entry,
                ),
                .import_namespace_specifier => try checkImportName(
                    allocator,
                    diagnostics,
                    tree,
                    specifier_index,
                    source,
                    "*",
                    declaration.import_kind,
                    entry,
                ),
                .import_specifier => |specifier| {
                    const imported = moduleName(tree, specifier.imported) orelse continue;
                    const import_kind: ast.ImportOrExportKind = if (declaration.import_kind == .type)
                        .type
                    else
                        specifier.import_kind;
                    try checkImportName(
                        allocator,
                        diagnostics,
                        tree,
                        specifier.imported,
                        source,
                        imported,
                        import_kind,
                        entry,
                    );
                },
                else => {},
            }
        }
    }
}

fn checkExportNamedDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.ExportNamedDeclaration,
    restrictions: core.NoRestrictedImports,
) Allocator.Error!void {
    const source = stringLiteralValue(tree, declaration.source) orelse return;

    for (0..restrictions.count) |index| {
        const entry = restrictions.at(index);
        if (!entryMatches(entry, source)) continue;

        if (entry.import_names.count == 0 and entry.allow_import_names.count == 0) {
            if (declaration.export_kind == .type and entry.allow_type_imports) continue;
            try reportModule(allocator, diagnostics, tree, declaration.source, source, entry);
            continue;
        }

        for (tree.extra(declaration.specifiers)) |specifier_index| {
            const specifier = switch (tree.data(specifier_index)) {
                .export_specifier => |specifier| specifier,
                else => continue,
            };
            const imported = moduleName(tree, specifier.local) orelse continue;
            const import_kind: ast.ImportOrExportKind = if (declaration.export_kind == .type)
                .type
            else
                specifier.export_kind;
            try checkImportName(
                allocator,
                diagnostics,
                tree,
                specifier.local,
                source,
                imported,
                import_kind,
                entry,
            );
        }
    }
}

fn checkExportAllDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.ExportAllDeclaration,
    restrictions: core.NoRestrictedImports,
) Allocator.Error!void {
    const source = stringLiteralValue(tree, declaration.source) orelse return;

    for (0..restrictions.count) |index| {
        const entry = restrictions.at(index);
        if (!entryMatches(entry, source)) continue;

        if (entry.import_names.count == 0 and entry.allow_import_names.count == 0) {
            if (declaration.export_kind == .type and entry.allow_type_imports) continue;
            try reportModule(allocator, diagnostics, tree, declaration.source, source, entry);
            continue;
        }

        try checkImportName(
            allocator,
            diagnostics,
            tree,
            if (declaration.exported == .null) declaration.source else declaration.exported,
            source,
            "*",
            declaration.export_kind,
            entry,
        );
    }
}

fn checkImportName(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    node: ast.NodeIndex,
    source: []const u8,
    name: []const u8,
    import_kind: ast.ImportOrExportKind,
    entry: *const core.NoRestrictedImportEntry,
) Allocator.Error!void {
    if (entry.allow_type_imports and import_kind == .type) return;

    if (entry.import_names.count > 0 and !entry.import_names.contains(name)) return;
    if (entry.allow_import_names.count > 0 and entry.allow_import_names.contains(name)) return;

    if (entry.import_names.count == 0 and entry.allow_import_names.count == 0) {
        try reportModule(allocator, diagnostics, tree, node, source, entry);
        return;
    }

    try reportImportName(allocator, diagnostics, tree, node, source, name, entry);
}

fn entryMatches(entry: *const core.NoRestrictedImportEntry, source: []const u8) bool {
    return switch (entry.kind) {
        .path => std.mem.eql(u8, entry.source(), source),
        .pattern => wildcardMatches(entry.source(), source),
    };
}

fn wildcardMatches(pattern: []const u8, source: []const u8) bool {
    if (pattern.len == 0) return false;
    if (std.mem.indexOfScalar(u8, pattern, '*') == null) {
        return std.mem.eql(u8, pattern, source);
    }

    var source_index: usize = 0;
    var part_index: usize = 0;
    var parts = std.mem.splitScalar(u8, pattern, '*');
    while (parts.next()) |part| : (part_index += 1) {
        if (part.len == 0) continue;

        if (part_index == 0 and pattern[0] != '*') {
            if (!std.mem.startsWith(u8, source, part)) return false;
            source_index = part.len;
            continue;
        }

        const found = std.mem.indexOf(u8, source[source_index..], part) orelse return false;
        source_index += found + part.len;
    }

    if (pattern[pattern.len - 1] != '*') {
        var last_parts = std.mem.splitScalar(u8, pattern, '*');
        var last: []const u8 = "";
        while (last_parts.next()) |part| {
            if (part.len > 0) last = part;
        }
        return std.mem.endsWith(u8, source, last);
    }

    return true;
}

fn moduleName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn stringLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn reportModule(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    node: ast.NodeIndex,
    source: []const u8,
    entry: *const core.NoRestrictedImportEntry,
) Allocator.Error!void {
    if (entry.message()) |message| {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(node),
            "'{s}' import is restricted from being used. {s}",
            .{ source, message },
        );
        return;
    }

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(node),
        "'{s}' import is restricted from being used.",
        .{source},
    );
}

fn reportImportName(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    node: ast.NodeIndex,
    source: []const u8,
    name: []const u8,
    entry: *const core.NoRestrictedImportEntry,
) Allocator.Error!void {
    if (entry.message()) |message| {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(node),
            "'{s}' import from '{s}' is restricted. {s}",
            .{ name, source, message },
        );
        return;
    }

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(node),
        "'{s}' import from '{s}' is restricted.",
        .{ name, source },
    );
}
