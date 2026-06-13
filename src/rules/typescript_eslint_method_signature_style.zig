const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/method-signature-style";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    signature: ast.TSMethodSignature,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (signature.kind != .method) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Shorthand method signature is forbidden. Use a function property instead.",
        tree.span(index),
    );
}
