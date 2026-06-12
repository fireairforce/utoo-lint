const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-inner-declarations";

pub fn checkFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (function.type != .function_declaration) return;
    if (!isInnerDeclaration(tree, ctx)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Move function declaration to program root or function body root.",
        tree.span(index),
    );
}

fn isInnerDeclaration(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    const parent = ctx.path.parent() orelse return false;

    switch (tree.data(parent)) {
        .program,
        .function_body,
        => return false,

        .export_named_declaration,
        .export_default_declaration,
        => {
            const grandparent = ctx.path.ancestor(2) orelse return true;
            return switch (tree.data(grandparent)) {
                .program,
                .function_body,
                => false,
                else => true,
            };
        },

        else => return true,
    }
}
