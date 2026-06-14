const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-plusplus";

pub const Options = struct {
    allow_for_loop_afterthoughts: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try addDiagnostic(allocator, diagnostics, tree, index);
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (options.allow_for_loop_afterthoughts and isForLoopAfterthought(tree, index, ctx)) return;
    try addDiagnostic(allocator, diagnostics, tree, index);
}

fn addDiagnostic(
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
        "Unary operator '++' or '--' used.",
        tree.span(index),
    );
}

fn isForLoopAfterthought(tree: *const ast.Tree, index: ast.NodeIndex, ctx: *traverser.basic.Ctx) bool {
    const parent = ctx.path.ancestor(1) orelse return false;
    if (isForStatementUpdate(tree, index, parent)) return true;
    if (isSequenceForStatementUpdate(tree, parent, ctx.path.ancestor(2))) return true;

    const parenthesized = switch (tree.data(parent)) {
        .parenthesized_expression => |parenthesized| parenthesized,
        else => return false,
    };
    if (parenthesized.expression != index) return false;

    const grandparent = ctx.path.ancestor(2) orelse return false;
    if (isForStatementUpdate(tree, parent, grandparent)) return true;
    return isSequenceForStatementUpdate(tree, grandparent, ctx.path.ancestor(3));
}

fn isForStatementUpdate(tree: *const ast.Tree, update: ast.NodeIndex, parent: ast.NodeIndex) bool {
    return switch (tree.data(parent)) {
        .for_statement => |statement| statement.update == update,
        else => false,
    };
}

fn isSequenceForStatementUpdate(tree: *const ast.Tree, sequence: ast.NodeIndex, grandparent: ?ast.NodeIndex) bool {
    if (tree.data(sequence) != .sequence_expression) return false;
    const for_index = grandparent orelse return false;
    return isForStatementUpdate(tree, sequence, for_index);
}
