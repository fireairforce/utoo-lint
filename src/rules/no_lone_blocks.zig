const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-lone-blocks";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    block: ast.BlockStatement,
    index: ast.NodeIndex,
    parent: ast.NodeIndex,
) Allocator.Error!void {
    if (!isStatementListParent(tree.data(parent))) return;
    if (hasBlockScopedBinding(tree, block)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Block is unnecessary.",
        tree.span(index),
    );
}

fn isStatementListParent(data: ast.NodeData) bool {
    return switch (data) {
        .program,
        .block_statement,
        => true,
        else => false,
    };
}

fn hasBlockScopedBinding(tree: *const ast.Tree, block: ast.BlockStatement) bool {
    const statements = tree.extra(block.body);
    for (statements) |statement| {
        switch (tree.data(statement)) {
            .variable_declaration => |declaration| switch (declaration.kind) {
                .@"var" => {},
                .let, .@"const", .using, .await_using => return true,
            },
            .class => |class| {
                if (class.type == .class_declaration) return true;
            },
            .function => |function| {
                if (function.type == .function_declaration) return true;
            },
            else => {},
        }
    }

    return false;
}
