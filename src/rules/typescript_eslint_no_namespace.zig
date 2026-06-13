const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-namespace";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.TSModuleDeclaration,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (declaration.declare) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "TypeScript namespaces are not allowed.",
        tree.span(index),
    );
}
