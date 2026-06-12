const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const no_new_symbol = @import("no_new_symbol.zig");
const symbol_description = @import("symbol_description.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    check_no_new_symbol: bool,
    check_symbol_description: bool,
) Allocator.Error!void {
    if (!check_no_new_symbol and !check_symbol_description) return;

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
        .check_no_new_symbol = check_no_new_symbol,
        .check_symbol_description = check_symbol_description,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,
    check_no_new_symbol: bool,
    check_symbol_description: bool,

    pub fn enter_new_expression(
        self: *Visitor,
        expression: ast.NewExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.check_no_new_symbol and isGlobalSymbolReference(ctx.tree, self.symbol_table, expression.callee)) {
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .@"error",
                no_new_symbol.id,
                "`Symbol` cannot be called as a constructor.",
                ctx.tree.span(index),
            );
        }

        return .proceed;
    }

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.check_symbol_description and
            call.arguments.len == 0 and
            isGlobalSymbolReference(ctx.tree, self.symbol_table, call.callee))
        {
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                symbol_description.id,
                "Expected Symbol to have a description.",
                ctx.tree.span(index),
            );
        }

        return .proceed;
    }
};

fn isGlobalSymbolReference(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) bool {
    const unwrapped = unwrapTransparent(tree, index);
    const name = identifierReferenceName(tree, unwrapped) orelse return false;

    return std.mem.eql(u8, name, "Symbol") and isUnresolvedReference(symbol_table, unwrapped);
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
