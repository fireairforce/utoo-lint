const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "curly";

pub fn checkIfStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.IfStatement,
) Allocator.Error!void {
    try checkBody(allocator, diagnostics, tree, statement.consequent);

    if (statement.alternate == .null) return;
    if (tree.data(statement.alternate) == .if_statement) return;

    try checkBody(allocator, diagnostics, tree, statement.alternate);
}

pub fn checkBody(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.NodeIndex,
) Allocator.Error!void {
    if (body == .null) return;
    if (tree.data(body) == .block_statement) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Expected a block statement.",
        tree.span(body),
    );
}
