const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-else-return";

pub const Options = struct {
    allow_else_if: bool = true,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.IfStatement,
) Allocator.Error!void {
    return checkWithOptions(allocator, diagnostics, tree, statement, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.IfStatement,
    options: Options,
) Allocator.Error!void {
    if (statement.alternate == .null) return;
    if (options.allow_else_if) {
        switch (tree.data(statement.alternate)) {
            .if_statement => return,
            else => {},
        }
    }
    if (!alwaysExits(tree, statement.consequent)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unnecessary else after return.",
        tree.span(statement.alternate),
    );
}

fn alwaysExits(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .return_statement,
        .throw_statement,
        .break_statement,
        .continue_statement,
        => true,
        .block_statement => |block| blockAlwaysExits(tree, block),
        .if_statement => |statement| statement.alternate != .null and
            alwaysExits(tree, statement.consequent) and
            alwaysExits(tree, statement.alternate),
        else => false,
    };
}

fn blockAlwaysExits(tree: *const ast.Tree, block: ast.BlockStatement) bool {
    if (block.body.len == 0) return false;

    const statements = tree.extra(block.body);
    return alwaysExits(tree, statements[statements.len - 1]);
}
