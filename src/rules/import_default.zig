const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const export_map = @import("import_export_map.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "import/default";

pub fn run(
    allocator: Allocator,
    io: std.Io,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    file_path: []const u8,
) Allocator.Error!void {
    const program = switch (tree.data(tree.root)) {
        .program => |program| program,
        else => return,
    };

    for (tree.extra(program.body)) |statement_index| {
        const declaration = switch (tree.data(statement_index)) {
            .import_declaration => |declaration| declaration,
            else => continue,
        };
        if (declaration.import_kind == .type) continue;
        const default_specifier = defaultSpecifier(tree, declaration) orelse continue;
        const source = export_map.importSource(tree, declaration) orelse continue;

        const resolved = try export_map.resolveRelativeModule(allocator, io, file_path, source) orelse continue;
        defer allocator.free(resolved);

        var map = try export_map.readExportMap(allocator, io, resolved) orelse continue;
        defer map.deinit();
        if (map.has_default) continue;

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .@"error",
            id,
            tree.span(default_specifier),
            "No default export found in imported module \"{s}\".",
            .{source},
        );
    }
}

fn defaultSpecifier(tree: *const ast.Tree, declaration: ast.ImportDeclaration) ?ast.NodeIndex {
    for (tree.extra(declaration.specifiers)) |specifier_index| {
        switch (tree.data(specifier_index)) {
            .import_default_specifier => return specifier_index,
            else => {},
        }
    }
    return null;
}
