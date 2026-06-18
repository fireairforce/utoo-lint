const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "one-var";

pub const Options = struct {
    check_var: bool = true,
    check_let: bool = true,
    check_const: bool = true,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    try checkWithOptions(allocator, diagnostics, tree, declaration, index, ctx, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (!shouldCheckKind(declaration.kind, options)) return;
    if (declaration.declarators.len < 2) return;
    if (isForStatementInit(tree, index, ctx)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Split variable declarations into multiple statements.",
        tree.span(index),
    );
}

fn shouldCheckKind(kind: ast.VariableKind, options: Options) bool {
    return switch (kind) {
        .@"var" => options.check_var,
        .let => options.check_let,
        .@"const" => options.check_const,
        .using, .await_using => true,
    };
}

fn isForStatementInit(tree: *const ast.Tree, index: ast.NodeIndex, ctx: *traverser.basic.Ctx) bool {
    const parent_index = ctx.path.ancestor(1) orelse return false;
    return switch (tree.data(parent_index)) {
        .for_statement => |statement| statement.init == index,
        else => false,
    };
}
