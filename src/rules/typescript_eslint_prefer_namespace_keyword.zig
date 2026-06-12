const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/prefer-namespace-keyword";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.TSModuleDeclaration,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (declaration.kind != .module) return;

    switch (tree.data(declaration.id)) {
        .string_literal => return,
        else => {},
    }

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Use 'namespace' instead of 'module' to declare custom TypeScript modules.",
        tree.span(index),
    );
}
