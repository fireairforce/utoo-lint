const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;
const SymbolId = traverser.semantic.SymbolId;

pub const id = "no-var";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    scope_tree: traverser.semantic.ScopeTree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .scope_tree = scope_tree,
        .symbol_table = symbol_table,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    scope_tree: traverser.semantic.ScopeTree,
    symbol_table: traverser.semantic.SymbolTable,

    pub fn enter_variable_declaration(
        self: *Visitor,
        declaration: ast.VariableDeclaration,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (declaration.kind != .@"var") return .proceed;
        if (isDeclareGlobal(ctx.tree, self.symbol_table, index)) return .proceed;

        const diagnostic_span = ctx.tree.span(index);
        if (try canFix(
            self.allocator,
            ctx.tree,
            declaration,
            index,
            self.scope_tree,
            self.symbol_table,
        )) {
            if (varKeywordSpan(ctx.tree, declaration, diagnostic_span)) |fix_span| {
                try core.addDiagnosticWithFix(
                    self.allocator,
                    self.diagnostics,
                    .warning,
                    id,
                    "Use 'let' or 'const' instead of 'var'.",
                    diagnostic_span,
                    .{ .span = fix_span, .replacement = "let" },
                );
                return .proceed;
            }
        }

        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            "Use 'let' or 'const' instead of 'var'.",
            diagnostic_span,
        );
        return .proceed;
    }
};

fn isDeclareGlobal(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) bool {
    const parent = symbol_table.parentOf(index) orelse return false;
    if (tree.data(parent) != .ts_module_block) return false;
    const grandparent = symbol_table.parentOf(parent) orelse return false;
    return tree.data(grandparent) == .ts_global_declaration;
}

fn canFix(
    allocator: Allocator,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    index: ast.NodeIndex,
    scope_tree: traverser.semantic.ScopeTree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!bool {
    const parent = symbol_table.parentOf(index) orelse return false;
    if (tree.data(parent) == .switch_case) return false;
    if (!hasSafeStatementPosition(tree, index, parent)) return false;

    var symbols: std.ArrayList(SymbolId) = .empty;
    defer symbols.deinit(allocator);

    for (tree.extra(declaration.declarators)) |declarator_index| {
        const declarator = switch (tree.data(declarator_index)) {
            .variable_declarator => |value| value,
            else => continue,
        };
        try collectBindingSymbols(tree, symbol_table, declarator.id, &symbols, allocator);
    }
    if (symbols.items.len == 0) return false;

    const scope_span = nearestScopeNodeSpan(tree, symbol_table, index) orelse return false;
    const loop = enclosingLoop(tree, symbol_table, index);
    const loop_assignee = isLoopAssignee(tree, index, parent);
    if (loop != null and !loop_assignee and !isDeclarationInitialized(tree, declaration)) return false;

    for (symbols.items) |symbol_id| {
        const symbol = symbol_table.getSymbol(symbol_id);
        if (scope_tree.getScope(symbol.scope).kind == .global) return false;
        if (symbol_table.symbolDecls(symbol_id).len >= 2) return false;
        if (std.mem.eql(u8, tree.string(symbol.name), "let")) return false;

        const declaration_start = bindingDeclarationStart(tree, symbol_table, symbol_id) orelse return false;
        var uses = symbol_table.symbolUses(symbol_id);
        while (uses.next()) |reference_node| {
            const reference_span = tree.span(reference_node);
            if (!spanInside(reference_span, scope_span)) return false;
            if (reference_span.start < declaration_start) return false;

            if (loop != null) {
                const reference_id = symbol_table.model.referenceOf(reference_node) orelse continue;
                const reference = symbol_table.getReference(reference_id);
                if (enclosingFunctionScope(scope_tree, reference.scope) != enclosingFunctionScope(scope_tree, symbol.scope)) {
                    return false;
                }
            }
        }
    }

    for (tree.extra(declaration.declarators)) |declarator_index| {
        const declarator = switch (tree.data(declarator_index)) {
            .variable_declarator => |value| value,
            else => continue,
        };
        if (try hasReferenceInTdz(allocator, tree, symbol_table, declarator)) return false;
    }

    return true;
}

fn collectBindingSymbols(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
    symbols: *std.ArrayList(SymbolId),
    allocator: Allocator,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(index)) {
        .binding_identifier => {
            const symbol_id = symbol_table.symbolOf(index) orelse return;
            for (symbols.items) |existing| {
                if (existing == symbol_id) return;
            }
            try symbols.append(allocator, symbol_id);
        },
        .assignment_pattern => |pattern| try collectBindingSymbols(tree, symbol_table, pattern.left, symbols, allocator),
        .binding_rest_element => |element| try collectBindingSymbols(tree, symbol_table, element.argument, symbols, allocator),
        .array_pattern => |pattern| {
            for (tree.extra(pattern.elements)) |element| {
                try collectBindingSymbols(tree, symbol_table, element, symbols, allocator);
            }
            try collectBindingSymbols(tree, symbol_table, pattern.rest, symbols, allocator);
        },
        .object_pattern => |pattern| {
            for (tree.extra(pattern.properties)) |property_index| {
                const property = switch (tree.data(property_index)) {
                    .binding_property => |value| value,
                    else => continue,
                };
                try collectBindingSymbols(tree, symbol_table, property.value, symbols, allocator);
            }
            try collectBindingSymbols(tree, symbol_table, pattern.rest, symbols, allocator);
        },
        else => {},
    }
}

fn hasSafeStatementPosition(tree: *const ast.Tree, index: ast.NodeIndex, parent: ast.NodeIndex) bool {
    return switch (tree.data(parent)) {
        .program,
        .function_body,
        .block_statement,
        .static_block,
        .ts_module_block,
        => true,
        .for_statement => |statement| statement.init == index,
        .for_in_statement => |statement| statement.left == index,
        .for_of_statement => |statement| statement.left == index,
        else => false,
    };
}

fn isLoopAssignee(tree: *const ast.Tree, index: ast.NodeIndex, parent: ast.NodeIndex) bool {
    return switch (tree.data(parent)) {
        .for_in_statement => |statement| statement.left == index,
        .for_of_statement => |statement| statement.left == index,
        else => false,
    };
}

fn isDeclarationInitialized(tree: *const ast.Tree, declaration: ast.VariableDeclaration) bool {
    for (tree.extra(declaration.declarators)) |declarator_index| {
        const declarator = switch (tree.data(declarator_index)) {
            .variable_declarator => |value| value,
            else => return false,
        };
        if (declarator.init == .null) return false;
    }
    return true;
}

fn nearestScopeNodeSpan(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) ?ast.Span {
    var current: ?ast.NodeIndex = index;
    while (current) |node| : (current = symbol_table.parentOf(node)) {
        switch (tree.data(node)) {
            .program,
            .function_body,
            .block_statement,
            .switch_statement,
            .for_statement,
            .for_in_statement,
            .for_of_statement,
            .static_block,
            .ts_module_block,
            => return tree.span(node),
            else => {},
        }
    }
    return null;
}

fn enclosingLoop(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) ?ast.NodeIndex {
    var current = symbol_table.parentOf(index);
    while (current) |node| : (current = symbol_table.parentOf(node)) {
        switch (tree.data(node)) {
            .for_statement,
            .for_in_statement,
            .for_of_statement,
            .while_statement,
            .do_while_statement,
            => return node,
            .function,
            .arrow_function_expression,
            => return null,
            else => {},
        }
    }
    return null;
}

fn enclosingFunctionScope(
    scope_tree: traverser.semantic.ScopeTree,
    start: traverser.semantic.ScopeId,
) traverser.semantic.ScopeId {
    var current = start;
    while (current != .none) {
        const scope = scope_tree.getScope(current);
        if (scope.kind == .function or scope.kind == .global) return current;
        current = scope.parent;
    }
    return .root;
}

fn bindingDeclarationStart(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    symbol_id: SymbolId,
) ?u32 {
    const declarations = symbol_table.symbolDecls(symbol_id);
    if (declarations.len == 0) return null;

    var current: ?ast.NodeIndex = declarations[0];
    while (current) |node| : (current = symbol_table.parentOf(node)) {
        if (tree.data(node) == .variable_declarator) return tree.span(node).start;
    }
    return tree.span(declarations[0]).start;
}

fn hasReferenceInTdz(
    allocator: Allocator,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    declarator: ast.VariableDeclarator,
) Allocator.Error!bool {
    if (declarator.init == .null) return false;

    const id_span = tree.span(declarator.id);
    const init_span = tree.span(declarator.init);
    const function_initializer = switch (tree.data(declarator.init)) {
        .function, .arrow_function_expression => true,
        else => false,
    };
    var symbols: std.ArrayList(SymbolId) = .empty;
    defer symbols.deinit(allocator);
    try collectBindingSymbols(tree, symbol_table, declarator.id, &symbols, allocator);

    for (symbols.items) |symbol_id| {
        var uses = symbol_table.symbolUses(symbol_id);
        while (uses.next()) |reference_node| {
            const reference_span = tree.span(reference_node);
            if (spanInside(reference_span, id_span)) return true;
            if (!spanInside(reference_span, init_span)) continue;
            if (!function_initializer) return true;
        }
    }
    return false;
}

fn varKeywordSpan(tree: *const ast.Tree, declaration: ast.VariableDeclaration, span: ast.Span) ?ast.Span {
    const declarators = tree.extra(declaration.declarators);
    if (declarators.len == 0) return null;
    const search_end = tree.span(declarators[0]).start;
    if (span.start > search_end or search_end > tree.source.len) return null;

    var offset: usize = @intCast(span.start);
    const end: usize = @intCast(search_end);
    while (offset + 3 <= end) : (offset += 1) {
        if (!std.mem.eql(u8, tree.source[offset .. offset + 3], "var")) continue;
        if (offset > 0 and isIdentifierByte(tree.source[offset - 1])) continue;
        if (offset + 3 < tree.source.len and isIdentifierByte(tree.source[offset + 3])) continue;
        if (insideComment(tree, @intCast(offset))) continue;
        return .{ .start = @intCast(offset), .end = @intCast(offset + 3) };
    }
    return null;
}

fn insideComment(tree: *const ast.Tree, offset: u32) bool {
    var low: usize = 0;
    var high = tree.comments.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (tree.comments[middle].span.end <= offset) {
            low = middle + 1;
        } else {
            high = middle;
        }
    }
    return low < tree.comments.len and
        offset >= tree.comments[low].span.start and
        offset < tree.comments[low].span.end;
}

fn isIdentifierByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '$' or byte >= 0x80;
}

fn spanInside(inner: ast.Span, outer: ast.Span) bool {
    return inner.start >= outer.start and inner.end <= outer.end;
}
