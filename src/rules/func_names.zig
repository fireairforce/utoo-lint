const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "func-names";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (function.id != .null) return;
    if (!requiresName(tree, function, ctx)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected unnamed function.",
        tree.span(index),
    );
}

fn requiresName(tree: *const ast.Tree, function: ast.Function, ctx: *traverser.basic.Ctx) bool {
    return switch (function.type) {
        .function_expression => !isMethodParent(tree, ctx),
        .function_declaration => isExportDefaultDeclarationParent(tree, ctx),
        else => false,
    };
}

fn isMethodParent(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    const parent = ctx.path.parent() orelse return false;
    return switch (tree.data(parent)) {
        .method_definition => true,
        .object_property => |property| property.method,
        else => false,
    };
}

fn isExportDefaultDeclarationParent(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    const parent = ctx.path.parent() orelse return false;
    return switch (tree.data(parent)) {
        .export_default_declaration => true,
        else => false,
    };
}
