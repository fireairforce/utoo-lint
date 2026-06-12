const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-var-requires";

const ReferenceLookup = std.AutoHashMap(ast.NodeIndex, traverser.semantic.SymbolId);

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    if (std.mem.indexOf(u8, tree.source, "require") == null) return;

    var reference_lookup = try buildReferenceLookup(allocator, symbol_table);
    defer reference_lookup.deinit();

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .reference_lookup = &reference_lookup,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    reference_lookup: *const ReferenceLookup,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (!self.isGlobalRequireReference(ctx.tree, call.callee)) return .proceed;
        if (!hasDisallowedParent(ctx.tree, index, ctx)) return .proceed;

        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .@"error",
            id,
            "Require statement not part of import statement.",
            ctx.tree.span(index),
        );
        return .proceed;
    }

    fn isGlobalRequireReference(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) bool {
        const name = identifierReferenceName(tree, index) orelse return false;
        if (!std.mem.eql(u8, name, "require")) return false;

        return (self.reference_lookup.get(index) orelse .none) == .none;
    }
};

fn hasDisallowedParent(tree: *const ast.Tree, index: ast.NodeIndex, ctx: *traverser.basic.Ctx) bool {
    var child_index = index;
    var depth: usize = 1;

    while (ctx.path.ancestor(depth)) |parent_index| : (depth += 1) {
        const parent = tree.data(parent_index);
        switch (parent) {
            .chain_expression => |chain| {
                if (chain.expression != child_index) return false;
                child_index = parent_index;
                continue;
            },
            .parenthesized_expression => |parenthesized| {
                if (parenthesized.expression != child_index) return false;
                child_index = parent_index;
                continue;
            },
            .call_expression,
            .member_expression,
            .new_expression,
            .ts_as_expression,
            .ts_type_assertion,
            .variable_declarator,
            => return true,
            else => return false,
        }
    }

    return false;
}

fn buildReferenceLookup(
    allocator: Allocator,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!ReferenceLookup {
    var lookup = ReferenceLookup.init(allocator);
    errdefer lookup.deinit();
    try lookup.ensureTotalCapacity(@intCast(symbol_table.references.len));

    var iter = symbol_table.iterReferences();
    while (iter.next()) |entry| {
        try lookup.put(entry.reference.node, symbol_table.referenceSymbol(entry.id));
    }

    return lookup;
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}
