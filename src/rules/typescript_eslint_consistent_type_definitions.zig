const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/consistent-type-definitions";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.TSTypeAliasDeclaration,
    index: ast.NodeIndex,
) Allocator.Error!void {
    _ = index;

    if (tree.data(declaration.type_annotation) != .ts_type_literal) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Use an interface instead of a type.",
        tree.span(declaration.id),
    );
}
