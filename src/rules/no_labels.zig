const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-labels";

pub fn checkLabeledStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Labels are not allowed.",
        tree.span(index),
    );
}

pub fn checkBreakStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.BreakStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (statement.label == .null) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected label in break statement.",
        tree.span(index),
    );
}

pub fn checkContinueStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ContinueStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (statement.label == .null) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected label in continue statement.",
        tree.span(index),
    );
}
