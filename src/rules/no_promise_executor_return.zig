const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-promise-executor-return";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,

    pub fn enter_new_expression(
        self: *Visitor,
        expression: ast.NewExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (!isGlobalPromiseReference(ctx.tree, self.symbol_table, expression.callee)) return .proceed;
        const executor = promiseExecutor(ctx.tree, expression.arguments) orelse return .proceed;

        try checkExecutor(self.allocator, self.diagnostics, ctx.tree, executor);
        return .proceed;
    }
};

fn promiseExecutor(tree: *const ast.Tree, arguments: ast.IndexRange) ?ast.NodeIndex {
    if (arguments.len == 0) return null;

    const executor = unwrapTransparent(tree, tree.extra(arguments)[0]);
    return switch (tree.data(executor)) {
        .arrow_function_expression,
        .function,
        => executor,
        else => null,
    };
}

fn checkExecutor(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    executor: ast.NodeIndex,
) Allocator.Error!void {
    switch (tree.data(executor)) {
        .arrow_function_expression => |arrow| {
            if (arrow.expression) {
                try addDiagnostic(allocator, diagnostics, tree, arrow.body);
            } else {
                try scanFunctionBody(allocator, diagnostics, tree, arrow.body);
            }
        },
        .function => |function| try scanFunctionBody(allocator, diagnostics, tree, function.body),
        else => {},
    }
}

fn scanFunctionBody(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body_index: ast.NodeIndex,
) Allocator.Error!void {
    if (body_index == .null) return;

    const body = switch (tree.data(body_index)) {
        .function_body => |body| body,
        else => return,
    };

    try scanRange(allocator, diagnostics, tree, body.body);
}

fn scanNode(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(index)) {
        .return_statement => |statement| {
            if (statement.argument != .null) {
                try addDiagnostic(allocator, diagnostics, tree, index);
            }
        },
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
            try scanNode(allocator, diagnostics, tree, statement.finalizer);
        },
        .function,
        .arrow_function_expression,
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
        "Promise executor should not return a value.",
        tree.span(index),
    );
}

fn isGlobalPromiseReference(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) bool {
    const unwrapped = unwrapTransparent(tree, index);
    const name = identifierReferenceName(tree, unwrapped) orelse return false;

    return std.mem.eql(u8, name, "Promise") and isUnresolvedReference(symbol_table, unwrapped);
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;

    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |chain| current = chain.expression,
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            else => return current,
        }
    }

    return current;
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isUnresolvedReference(
    symbol_table: traverser.semantic.SymbolTable,
    node: ast.NodeIndex,
) bool {
    var iter = symbol_table.iterReferences();
    while (iter.next()) |entry| {
        if (entry.reference.node == node) {
            return symbol_table.referenceSymbol(entry.id) == .none;
        }
    }

    return false;
}
