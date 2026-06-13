const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const export_map = @import("import_export_map.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "import/no-named-as-default";

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
        const source = export_map.importSource(tree, declaration) orelse continue;

        const resolved = try export_map.resolveRelativeModule(allocator, io, file_path, source) orelse continue;
        defer allocator.free(resolved);

        var remote = try export_map.readExportMap(allocator, io, resolved) orelse continue;
        defer remote.deinit();
        if (!remote.has_default) continue;

        for (tree.extra(declaration.specifiers)) |specifier_index| {
            const specifier = switch (tree.data(specifier_index)) {
                .import_default_specifier => |specifier| specifier,
                else => continue,
            };
            const local = bindingIdentifierName(tree, specifier.local) orelse continue;
            if (std.mem.eql(u8, local, "default")) continue;
            if (!remote.hasNamed(local)) continue;

            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .@"error",
                id,
                tree.span(specifier_index),
                "Using exported name '{s}' as identifier for default import.",
                .{local},
            );
        }
    }
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}
