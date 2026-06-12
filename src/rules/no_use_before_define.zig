const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-use-before-define";

const SymbolId = traverser.semantic.SymbolId;
const DeclSymbolMap = std.AutoHashMap(ast.NodeIndex, SymbolId);

const InitRange = struct {
    symbol_id: SymbolId,
    span: ast.Span,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var decl_symbols = DeclSymbolMap.init(allocator);
    defer decl_symbols.deinit();

    var symbol_iter = symbol_table.iterSymbols();
    while (symbol_iter.next()) |entry| {
        if (!isLintableSymbol(entry.symbol.flags)) continue;
        for (symbol_table.symbolDecls(entry.id)) |decl| {
            try decl_symbols.put(decl, entry.id);
        }
    }

    var init_ranges: std.ArrayList(InitRange) = .empty;
    defer init_ranges.deinit(allocator);

    var visitor = InitVisitor{
        .allocator = allocator,
        .decl_symbols = &decl_symbols,
        .init_ranges = &init_ranges,
    };
    try traverser.basic.traverse(InitVisitor, tree, &visitor);
    std.mem.sort(InitRange, init_ranges.items, {}, lessThanInitRange);

    var reference_iter = symbol_table.iterReferences();
    while (reference_iter.next()) |entry| {
        const reference = entry.reference;
        if (reference.kind != .value) continue;

        const symbol_id = symbol_table.referenceSymbol(entry.id);
        if (symbol_id == .none) continue;

        const symbol = symbol_table.getSymbol(symbol_id);
        if (!isLintableSymbol(symbol.flags)) continue;

        const decls = symbol_table.symbolDecls(symbol_id);
        if (decls.len == 0) continue;

        const reference_span = tree.span(reference.node);
        const definition_span = tree.span(decls[0]);
        if (reference_span.end >= definition_span.end and !isInInitializer(symbol_id, reference_span, init_ranges.items)) {
            continue;
        }

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            reference_span,
            "'{s}' was used before it was defined.",
            .{tree.string(reference.name)},
        );
    }
}

const InitVisitor = struct {
    allocator: Allocator,
    decl_symbols: *const DeclSymbolMap,
    init_ranges: *std.ArrayList(InitRange),

    pub fn enter_variable_declarator(
        self: *InitVisitor,
        declarator: ast.VariableDeclarator,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (declarator.init == .null) return .proceed;
        try self.collectBinding(ctx.tree, declarator.id, ctx.tree.span(declarator.init));
        return .proceed;
    }

    fn collectBinding(
        self: *InitVisitor,
        tree: *const ast.Tree,
        index: ast.NodeIndex,
        init_span: ast.Span,
    ) Allocator.Error!void {
        if (index == .null) return;

        switch (tree.data(index)) {
            .binding_identifier => {
                const symbol_id = self.decl_symbols.get(index) orelse return;
                try self.init_ranges.append(self.allocator, .{
                    .symbol_id = symbol_id,
                    .span = init_span,
                });
            },
            .assignment_pattern => |pattern| try self.collectBinding(tree, pattern.left, init_span),
            .binding_rest_element => |element| try self.collectBinding(tree, element.argument, init_span),
            .array_pattern => |pattern| {
                for (tree.extra(pattern.elements)) |element| {
                    try self.collectBinding(tree, element, init_span);
                }
                try self.collectBinding(tree, pattern.rest, init_span);
            },
            .object_pattern => |pattern| {
                for (tree.extra(pattern.properties)) |property_index| {
                    const property = switch (tree.data(property_index)) {
                        .binding_property => |property| property,
                        else => continue,
                    };
                    try self.collectBinding(tree, property.value, init_span);
                }
                try self.collectBinding(tree, pattern.rest, init_span);
            },
            else => {},
        }
    }
};

fn isInInitializer(symbol_id: SymbolId, reference_span: ast.Span, init_ranges: []const InitRange) bool {
    const start = lowerBoundInitRange(init_ranges, symbol_id);

    for (init_ranges[start..]) |range| {
        if (range.symbol_id != symbol_id) break;
        if (spanInside(reference_span, range.span)) return true;
    }
    return false;
}

fn lessThanInitRange(_: void, lhs: InitRange, rhs: InitRange) bool {
    return @intFromEnum(lhs.symbol_id) < @intFromEnum(rhs.symbol_id);
}

fn lowerBoundInitRange(init_ranges: []const InitRange, symbol_id: SymbolId) usize {
    const needle = @intFromEnum(symbol_id);
    var low: usize = 0;
    var high: usize = init_ranges.len;

    while (low < high) {
        const middle = low + (high - low) / 2;
        if (@intFromEnum(init_ranges[middle].symbol_id) < needle) {
            low = middle + 1;
        } else {
            high = middle;
        }
    }

    return low;
}

fn spanInside(span: ast.Span, container: ast.Span) bool {
    return span.start >= container.start and span.end <= container.end;
}

fn isLintableSymbol(flags: traverser.semantic.Symbol.Flags) bool {
    if (flags.ambient) return false;
    if (flags.type_import or flags.interface or flags.type_alias or flags.type_parameter) return false;
    return flags.inValueSpace() or flags.import;
}
