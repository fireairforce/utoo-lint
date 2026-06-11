const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-new-object";

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
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (isGlobalObjectReference(ctx.tree, self.symbol_table, expression.callee)) {
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                "Do not use Object as a constructor.",
                ctx.tree.span(index),
            );
        }

        return .proceed;
    }
};

fn isGlobalObjectReference(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) bool {
    const unwrapped = unwrapTransparent(tree, index);
    const name = identifierReferenceName(tree, unwrapped) orelse return false;

    return std.mem.eql(u8, name, "Object") and isUnresolvedReference(symbol_table, unwrapped);
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
