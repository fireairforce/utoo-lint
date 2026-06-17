const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/consistent-type-definitions";

pub fn checkTypeAliasDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.TSTypeAliasDeclaration,
    style: core.TypescriptEslintConsistentTypeDefinitionsStyle,
) Allocator.Error!void {
    if (style != .interface) return;
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

pub fn checkInterfaceDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.TSInterfaceDeclaration,
    style: core.TypescriptEslintConsistentTypeDefinitionsStyle,
) Allocator.Error!void {
    if (style != .type) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Use a type instead of an interface.",
        tree.span(declaration.id),
    );
}
