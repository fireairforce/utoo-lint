const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-useless-empty-export";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    program: ast.Program,
) Allocator.Error!void {
    const body = tree.extra(program.body);
    var module_statement_count: usize = 0;

    for (body) |statement_index| {
        if (isTopLevelModuleStatement(tree, statement_index)) {
            module_statement_count += 1;
        }
    }

    if (module_statement_count <= 1) return;

    for (body) |statement_index| {
        const declaration = switch (tree.data(statement_index)) {
            .export_named_declaration => |declaration| declaration,
            else => continue,
        };
        if (!isEmptyExport(tree, declaration)) continue;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .@"error",
            id,
            "`export {}` is unnecessary when another import or export exists.",
            tree.span(statement_index),
        );
    }
}

fn isTopLevelModuleStatement(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .import_declaration,
        .export_default_declaration,
        .export_all_declaration,
        .ts_import_equals_declaration,
        .ts_export_assignment,
        .ts_namespace_export_declaration,
        => true,
        .export_named_declaration => true,
        else => false,
    };
}

fn isEmptyExport(tree: *const ast.Tree, declaration: ast.ExportNamedDeclaration) bool {
    return declaration.declaration == .null and
        declaration.source == .null and
        tree.extra(declaration.specifiers).len == 0;
}
