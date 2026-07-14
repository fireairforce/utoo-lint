const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const array_constructor_fix = @import("array_constructor_fix.zig");
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-array-constructor";

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
        if (expression.type_arguments == .null and isDisallowedArrayConstructor(ctx.tree, self.symbol_table, expression.callee, expression.arguments)) {
            try addDiagnostic(self, ctx.tree, index, expression.callee, expression.arguments, false, &ctx.path);
        }

        return .proceed;
    }

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (call.type_arguments == .null and isDisallowedArrayConstructor(ctx.tree, self.symbol_table, call.callee, call.arguments)) {
            try addDiagnostic(self, ctx.tree, index, call.callee, call.arguments, call.optional, &ctx.path);
        }

        return .proceed;
    }

    fn addDiagnostic(
        self: *Visitor,
        tree: *const ast.Tree,
        index: ast.NodeIndex,
        callee: ast.NodeIndex,
        arguments: ast.IndexRange,
        optional: bool,
        path: anytype,
    ) Allocator.Error!void {
        try array_constructor_fix.addDiagnostic(
            self.allocator,
            self.diagnostics,
            tree,
            index,
            callee,
            arguments,
            optional,
            array_constructor_fix.needsAsiGuard(tree, index, path),
            .{},
            .warning,
            id,
            "Use an array literal instead of the Array constructor.",
        );
    }
};

fn isDisallowedArrayConstructor(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    callee: ast.NodeIndex,
    arguments: ast.IndexRange,
) bool {
    if (!isGlobalArrayReference(tree, symbol_table, callee)) return false;
    if (arguments.len != 1) return true;

    const argument = tree.extra(arguments)[0];
    return switch (tree.data(argument)) {
        .spread_element => true,
        else => false,
    };
}

fn isGlobalArrayReference(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) bool {
    const unwrapped = unwrapTransparent(tree, index);
    const name = identifierReferenceName(tree, unwrapped) orelse return false;

    return std.mem.eql(u8, name, "Array") and isUnresolvedReference(symbol_table, unwrapped);
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
