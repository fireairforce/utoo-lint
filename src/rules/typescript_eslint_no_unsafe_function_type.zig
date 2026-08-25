const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;
const SymbolId = traverser.semantic.SymbolId;
const ScopeId = traverser.semantic.ScopeId;

pub const id = "@typescript-eslint/no-unsafe-function-type";

const ReferenceInfo = struct {
    symbol: SymbolId,
    scope: ScopeId,
};
const ReferenceLookup = std.AutoHashMap(ast.NodeIndex, ReferenceInfo);

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    scope_tree: traverser.semantic.ScopeTree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var references = ReferenceLookup.init(allocator);
    defer references.deinit();

    var reference_iter = symbol_table.iterReferences();
    while (reference_iter.next()) |entry| {
        if (!std.mem.eql(u8, tree.string(entry.reference.name), "Function")) continue;
        try references.put(entry.reference.node, .{
            .symbol = symbol_table.referenceSymbol(entry.id),
            .scope = entry.reference.scope,
        });
    }

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .references = &references,
        .scope_tree = scope_tree,
        .symbol_table = symbol_table,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    references: *const ReferenceLookup,
    scope_tree: traverser.semantic.ScopeTree,
    symbol_table: traverser.semantic.SymbolTable,

    pub fn enter_ts_type_reference(
        self: *Visitor,
        reference: ast.TSTypeReference,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.check(ctx.tree, reference.type_name);
        return .proceed;
    }

    pub fn enter_ts_interface_heritage(
        self: *Visitor,
        heritage: ast.TSInterfaceHeritage,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.check(ctx.tree, heritage.expression);
        return .proceed;
    }

    pub fn enter_ts_class_implements(
        self: *Visitor,
        implementation: ast.TSClassImplements,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.check(ctx.tree, implementation.expression);
        return .proceed;
    }

    fn check(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        const name = switch (tree.data(index)) {
            .identifier_reference => |identifier| tree.string(identifier.name),
            else => return,
        };
        if (!std.mem.eql(u8, name, "Function")) return;

        const reference = self.references.get(index) orelse return;
        if (reference.symbol != .none) return;
        if (self.symbol_table.resolve(self.scope_tree, reference.scope, name) != null) return;

        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            "The `Function` type accepts any function-like value. Prefer explicitly defining function parameters and a return type.",
            tree.span(index),
        );
    }
};
