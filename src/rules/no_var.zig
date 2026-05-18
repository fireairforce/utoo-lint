const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-var";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (declaration.kind != .@"var") return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Use 'let' or 'const' instead of 'var'.",
        tree.span(index),
    );
}

