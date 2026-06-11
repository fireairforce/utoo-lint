const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-unsafe-finally";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.TryStatement,
) Allocator.Error!void {
    if (statement.finalizer == .null) return;

    try scanNode(allocator, diagnostics, tree, statement.finalizer);
}

fn scanNode(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(index)) {
        .return_statement,
        .throw_statement,
        .break_statement,
        .continue_statement,
        => try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Control flow statements in finally blocks are unsafe.",
            tree.span(index),
        ),
        .block_statement => |block| try scanRange(allocator, diagnostics, tree, block.body),
        .static_block => |block| try scanRange(allocator, diagnostics, tree, block.body),
        .if_statement => |statement| {
            try scanNode(allocator, diagnostics, tree, statement.consequent);
            try scanNode(allocator, diagnostics, tree, statement.alternate);
        },
        .switch_statement => |statement| {
            for (tree.extra(statement.cases)) |case_index| {
                const switch_case = switch (tree.data(case_index)) {
                    .switch_case => |switch_case| switch_case,
                    else => continue,
                };
                try scanRange(allocator, diagnostics, tree, switch_case.consequent);
            }
        },
        .for_statement => |statement| try scanNode(allocator, diagnostics, tree, statement.body),
        .for_in_statement => |statement| try scanNode(allocator, diagnostics, tree, statement.body),
        .for_of_statement => |statement| try scanNode(allocator, diagnostics, tree, statement.body),
        .while_statement => |statement| try scanNode(allocator, diagnostics, tree, statement.body),
        .do_while_statement => |statement| try scanNode(allocator, diagnostics, tree, statement.body),
        .with_statement => |statement| try scanNode(allocator, diagnostics, tree, statement.body),
        .labeled_statement => |statement| try scanNode(allocator, diagnostics, tree, statement.body),
        .try_statement => |statement| {
            try scanNode(allocator, diagnostics, tree, statement.block);
            if (statement.handler != .null) {
                const handler = switch (tree.data(statement.handler)) {
                    .catch_clause => |handler| handler,
                    else => return,
                };
                try scanNode(allocator, diagnostics, tree, handler.body);
            }
        },
        .function,
        .class,
        => return,
        else => return,
    }
}

fn scanRange(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    range: ast.IndexRange,
) Allocator.Error!void {
    for (tree.extra(range)) |child| {
        try scanNode(allocator, diagnostics, tree, child);
    }
}
