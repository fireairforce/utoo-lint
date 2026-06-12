const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "prefer-const";

const SymbolId = traverser.semantic.SymbolId;
const DeclSymbolMap = std.AutoHashMap(ast.NodeIndex, SymbolId);
const ReferenceLookup = std.AutoHashMap(ast.NodeIndex, SymbolId);

const Candidate = struct {
    node: ast.NodeIndex,
    name: []const u8,
    reassigned: bool = false,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var decl_symbols = DeclSymbolMap.init(allocator);
    defer decl_symbols.deinit();

    var reference_lookup = ReferenceLookup.init(allocator);
    defer reference_lookup.deinit();

    var candidates = std.AutoHashMap(SymbolId, Candidate).init(allocator);
    defer candidates.deinit();

    var symbol_iter = symbol_table.iterSymbols();
    while (symbol_iter.next()) |entry| {
        const symbol = entry.symbol;
        if (!symbol.flags.block_scoped_var or symbol.flags.const_var) continue;
        for (symbol_table.symbolDecls(entry.id)) |decl| {
            try decl_symbols.put(decl, entry.id);
        }
    }

    var ref_iter = symbol_table.iterReferences();
    while (ref_iter.next()) |entry| {
        try reference_lookup.put(entry.reference.node, symbol_table.referenceSymbol(entry.id));
    }

    var visitor = Visitor{
        .allocator = allocator,
        .decl_symbols = &decl_symbols,
        .reference_lookup = &reference_lookup,
        .candidates = &candidates,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);

    var candidate_iter = candidates.iterator();
    while (candidate_iter.next()) |entry| {
        const candidate = entry.value_ptr.*;
        if (candidate.reassigned) continue;

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(candidate.node),
            "'{s}' is never reassigned. Use 'const' instead.",
            .{candidate.name},
        );
    }
}

const Visitor = struct {
    allocator: Allocator,
    decl_symbols: *const DeclSymbolMap,
    reference_lookup: *const ReferenceLookup,
    candidates: *std.AutoHashMap(SymbolId, Candidate),

    pub fn enter_variable_declaration(
        self: *Visitor,
        declaration: ast.VariableDeclaration,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (declaration.kind != .let) return .proceed;

        for (ctx.tree.extra(declaration.declarators)) |declarator_index| {
            const declarator = switch (ctx.tree.data(declarator_index)) {
                .variable_declarator => |declarator| declarator,
                else => continue,
            };
            if (declarator.init == .null) continue;
            try self.collectCandidate(ctx.tree, declarator.id);
        }

        return .proceed;
    }

    pub fn enter_assignment_expression(
        self: *Visitor,
        expression: ast.AssignmentExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.markReassigned(ctx.tree, expression.left);
        return .proceed;
    }

    pub fn enter_update_expression(
        self: *Visitor,
        expression: ast.UpdateExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.markReassigned(ctx.tree, expression.argument);
        return .proceed;
    }

    fn collectCandidate(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        if (index == .null) return;

        switch (tree.data(index)) {
            .binding_identifier => |identifier| {
                const symbol_id = self.decl_symbols.get(index) orelse return;
                try self.candidates.put(symbol_id, .{
                    .node = index,
                    .name = tree.string(identifier.name),
                });
            },
            .assignment_pattern => |pattern| try self.collectCandidate(tree, pattern.left),
            .binding_rest_element => |element| try self.collectCandidate(tree, element.argument),
            .array_pattern => |pattern| {
                for (tree.extra(pattern.elements)) |element| {
                    try self.collectCandidate(tree, element);
                }
                try self.collectCandidate(tree, pattern.rest);
            },
            .object_pattern => |pattern| {
                for (tree.extra(pattern.properties)) |property_index| {
                    const property = switch (tree.data(property_index)) {
                        .binding_property => |property| property,
                        else => continue,
                    };
                    try self.collectCandidate(tree, property.value);
                }
                try self.collectCandidate(tree, pattern.rest);
            },
            else => {},
        }
    }

    fn markReassigned(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        if (index == .null) return;

        const unwrapped = unwrapTransparent(tree, index);
        switch (tree.data(unwrapped)) {
            .identifier_reference => {
                const symbol_id = self.reference_lookup.get(unwrapped) orelse return;
                if (self.candidates.getPtr(symbol_id)) |candidate| {
                    candidate.reassigned = true;
                }
            },
            .assignment_pattern => |pattern| try self.markReassigned(tree, pattern.left),
            .array_pattern => |pattern| {
                for (tree.extra(pattern.elements)) |element| {
                    try self.markReassigned(tree, element);
                }
                try self.markReassigned(tree, pattern.rest);
            },
            .object_pattern => |pattern| {
                for (tree.extra(pattern.properties)) |property_index| {
                    const property = switch (tree.data(property_index)) {
                        .binding_property => |property| property,
                        else => continue,
                    };
                    try self.markReassigned(tree, property.value);
                }
                try self.markReassigned(tree, pattern.rest);
            },
            else => {},
        }
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
