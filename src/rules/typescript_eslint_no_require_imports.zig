const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-require-imports";

const ReferenceLookup = std.AutoHashMap(ast.NodeIndex, traverser.semantic.SymbolId);

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
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
        if (self.isGlobalRequireReference(ctx.tree, call.callee)) {
            try self.addDiagnostic(ctx.tree, index);
        }
        return .proceed;
    }

    pub fn enter_ts_external_module_reference(
        self: *Visitor,
        _: ast.TSExternalModuleReference,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.addDiagnostic(ctx.tree, index);
        return .proceed;
    }

    fn isGlobalRequireReference(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) bool {
        const name = identifierReferenceName(tree, index) orelse return false;
        if (!std.mem.eql(u8, name, "require")) return false;

        return (self.reference_lookup.get(index) orelse .none) == .none;
    }

    fn addDiagnostic(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            "A `require()` style import is forbidden.",
            tree.span(index),
        );
    }
};

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
