const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "guard-for-in";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ForInStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (isGuarded(tree, statement.body)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "The body of a for-in should be wrapped in an if statement to filter unwanted properties from the prototype.",
        tree.span(index),
    );
}

fn isGuarded(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .empty_statement,
        .if_statement,
        => true,
        .block_statement => |block| blockIsGuarded(tree, block.body),
        else => false,
    };
}

fn blockIsGuarded(tree: *const ast.Tree, range: ast.IndexRange) bool {
    if (range.len == 0) return true;

    const statements = tree.extra(range);
    const first_if = switch (tree.data(statements[0])) {
        .if_statement => |statement| statement,
        else => return false,
    };

    if (range.len == 1) return true;

    return consequentIsContinue(tree, first_if.consequent);
}

fn consequentIsContinue(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .continue_statement => true,
        .block_statement => |block| blk: {
            if (block.body.len != 1) break :blk false;
            const statements = tree.extra(block.body);
            break :blk switch (tree.data(statements[0])) {
                .continue_statement => true,
                else => false,
            };
        },
        else => false,
    };
}
