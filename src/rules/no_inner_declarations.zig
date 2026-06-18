const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-inner-declarations";

pub const Mode = enum {
    functions,
    both,
};

pub fn checkFunction(
    _: Allocator,
    _: *core.DiagnosticList,
    _: *const ast.Tree,
    _: ast.Function,
    _: ast.NodeIndex,
    _: *traverser.basic.Ctx,
) Allocator.Error!void {}

pub fn checkVariableDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    mode: Mode,
) Allocator.Error!void {
    if (mode != .both or declaration.kind != .@"var") return;
    if (isAllowedDeclarationParent(tree, ctx.path.parent(), ctx.path.ancestor(2))) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Move variable declaration to program or function body root.",
        tree.span(index),
    );
}

fn isAllowedDeclarationParent(tree: *const ast.Tree, parent: ?ast.NodeIndex, grandparent: ?ast.NodeIndex) bool {
    const parent_index = parent orelse return true;
    switch (tree.data(parent_index)) {
        .program, .function_body, .static_block => return true,
        .export_named_declaration, .export_default_declaration => {
            const grandparent_index = grandparent orelse return false;
            return switch (tree.data(grandparent_index)) {
                .program, .function_body => true,
                else => false,
            };
        },
        else => return false,
    }
}
