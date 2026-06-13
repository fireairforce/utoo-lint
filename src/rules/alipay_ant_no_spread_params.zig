const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/ant/no-spread-params";

const SymbolId = traverser.semantic.SymbolId;
const ReferenceLookup = std.AutoHashMap(ast.NodeIndex, SymbolId);
const DeclSymbolMap = std.AutoHashMap(ast.NodeIndex, SymbolId);
const SymbolSet = std.AutoHashMap(SymbolId, void);

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var reference_lookup = ReferenceLookup.init(allocator);
    defer reference_lookup.deinit();

    var decl_symbols = DeclSymbolMap.init(allocator);
    defer decl_symbols.deinit();

    var symbol_iter = symbol_table.iterSymbols();
    while (symbol_iter.next()) |entry| {
        for (symbol_table.symbolDecls(entry.id)) |decl| {
            try decl_symbols.put(decl, entry.id);
        }
    }

    var reference_iter = symbol_table.iterReferences();
    while (reference_iter.next()) |entry| {
        if (entry.reference.kind != .value) continue;
        try reference_lookup.put(entry.reference.node, symbol_table.referenceSymbol(entry.id));
    }

    var param_symbols = SymbolSet.init(allocator);
    defer param_symbols.deinit();

    var param_visitor = ParamVisitor{
        .decl_symbols = &decl_symbols,
        .param_symbols = &param_symbols,
    };
    try traverser.basic.traverse(ParamVisitor, tree, &param_visitor);

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .reference_lookup = &reference_lookup,
        .param_symbols = &param_symbols,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const ParamVisitor = struct {
    decl_symbols: *const DeclSymbolMap,
    param_symbols: *SymbolSet,

    pub fn enter_formal_parameter(
        self: *ParamVisitor,
        parameter: ast.FormalParameter,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        switch (ctx.tree.data(parameter.pattern)) {
            .binding_identifier => try self.collectBinding(ctx.tree, parameter.pattern),
            else => {},
        }
        return .proceed;
    }

    fn collectBinding(self: *ParamVisitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        if (index == .null) return;

        switch (tree.data(index)) {
            .binding_identifier => {
                const symbol_id = self.decl_symbols.get(index) orelse return;
                if (symbol_id != .none) try self.param_symbols.put(symbol_id, {});
            },
            else => {},
        }
    }
};

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    reference_lookup: *const ReferenceLookup,
    param_symbols: *const SymbolSet,

    pub fn enter_jsx_spread_attribute(
        self: *Visitor,
        attribute: ast.JSXSpreadAttribute,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const argument = unwrapTransparent(ctx.tree, attribute.argument);
        switch (ctx.tree.data(argument)) {
            .identifier_reference => {},
            else => return .proceed,
        }

        const symbol_id = self.reference_lookup.get(argument) orelse return .proceed;
        if (symbol_id == .none or !self.param_symbols.contains(symbol_id)) return .proceed;

        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            "不要简单的使用类似`...props`的方式在组件中相互传值, 会造成代码维护/CR难度增大",
            ctx.tree.span(index),
        );
        return .proceed;
    }
};

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
