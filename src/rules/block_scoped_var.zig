const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "block-scoped-var";

const DeclSymbolMap = std.AutoHashMap(ast.NodeIndex, traverser.semantic.SymbolId);

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
        if (!entry.symbol.flags.isHoistingVar()) continue;

        for (symbol_table.symbolDecls(entry.id)) |decl| {
            try decl_symbols.put(decl, entry.id);
        }
    }

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
        .decl_symbols = &decl_symbols,
    };
    defer visitor.contexts.deinit(allocator);

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,
    decl_symbols: *const DeclSymbolMap,
    contexts: std.ArrayList(ast.Span) = .empty,

    pub fn enter_program(
        self: *Visitor,
        _: ast.Program,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.pushContext(ctx.tree.span(index));
        return .proceed;
    }

    pub fn exit_program(self: *Visitor, _: ast.Program, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.popContext();
    }

    pub fn enter_block_statement(
        self: *Visitor,
        _: ast.BlockStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.pushContext(ctx.tree.span(index));
        return .proceed;
    }

    pub fn exit_block_statement(self: *Visitor, _: ast.BlockStatement, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.popContext();
    }

    pub fn enter_function_body(
        self: *Visitor,
        _: ast.FunctionBody,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.pushContext(ctx.tree.span(index));
        return .proceed;
    }

    pub fn exit_function_body(self: *Visitor, _: ast.FunctionBody, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.popContext();
    }

    pub fn enter_for_statement(
        self: *Visitor,
        _: ast.ForStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.pushContext(ctx.tree.span(index));
        return .proceed;
    }

    pub fn exit_for_statement(self: *Visitor, _: ast.ForStatement, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.popContext();
    }

    pub fn enter_for_in_statement(
        self: *Visitor,
        _: ast.ForInStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.pushContext(ctx.tree.span(index));
        return .proceed;
    }

    pub fn exit_for_in_statement(self: *Visitor, _: ast.ForInStatement, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.popContext();
    }

    pub fn enter_for_of_statement(
        self: *Visitor,
        _: ast.ForOfStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.pushContext(ctx.tree.span(index));
        return .proceed;
    }

    pub fn exit_for_of_statement(self: *Visitor, _: ast.ForOfStatement, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.popContext();
    }

    pub fn enter_switch_statement(
        self: *Visitor,
        _: ast.SwitchStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.pushContext(ctx.tree.span(index));
        return .proceed;
    }

    pub fn exit_switch_statement(self: *Visitor, _: ast.SwitchStatement, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.popContext();
    }

    pub fn enter_catch_clause(
        self: *Visitor,
        _: ast.CatchClause,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.pushContext(ctx.tree.span(index));
        return .proceed;
    }

    pub fn exit_catch_clause(self: *Visitor, _: ast.CatchClause, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.popContext();
    }

    pub fn enter_static_block(
        self: *Visitor,
        _: ast.StaticBlock,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.pushContext(ctx.tree.span(index));
        return .proceed;
    }

    pub fn exit_static_block(self: *Visitor, _: ast.StaticBlock, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.popContext();
    }

    pub fn enter_variable_declaration(
        self: *Visitor,
        declaration: ast.VariableDeclaration,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (declaration.kind != .@"var") return .proceed;

        const context = self.currentContext() orelse return .proceed;
        for (ctx.tree.extra(declaration.declarators)) |declarator_index| {
            const declarator = switch (ctx.tree.data(declarator_index)) {
                .variable_declarator => |declarator| declarator,
                else => continue,
            };
            try self.checkBinding(ctx.tree, declarator.id, context);
        }

        return .proceed;
    }

    fn pushContext(self: *Visitor, span: ast.Span) Allocator.Error!void {
        try self.contexts.append(self.allocator, span);
    }

    fn popContext(self: *Visitor) void {
        _ = self.contexts.pop();
    }

    fn currentContext(self: *const Visitor) ?ast.Span {
        if (self.contexts.items.len == 0) return null;
        return self.contexts.items[self.contexts.items.len - 1];
    }

    fn checkBinding(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex, context: ast.Span) Allocator.Error!void {
        if (index == .null) return;

        switch (tree.data(index)) {
            .binding_identifier => |identifier| try self.checkIdentifier(tree, identifier, index, context),
            .assignment_pattern => |pattern| try self.checkBinding(tree, pattern.left, context),
            .binding_rest_element => |element| try self.checkBinding(tree, element.argument, context),
            .array_pattern => |pattern| {
                for (tree.extra(pattern.elements)) |element| {
                    try self.checkBinding(tree, element, context);
                }
                try self.checkBinding(tree, pattern.rest, context);
            },
            .object_pattern => |pattern| {
                for (tree.extra(pattern.properties)) |property_index| {
                    const property = switch (tree.data(property_index)) {
                        .binding_property => |property| property,
                        else => continue,
                    };
                    try self.checkBinding(tree, property.value, context);
                }
                try self.checkBinding(tree, pattern.rest, context);
            },
            else => {},
        }
    }

    fn checkIdentifier(
        self: *Visitor,
        tree: *const ast.Tree,
        identifier: ast.BindingIdentifier,
        index: ast.NodeIndex,
        context: ast.Span,
    ) Allocator.Error!void {
        const symbol_id = self.decl_symbols.get(index) orelse return;
        const definition_position = offsetToLineColumn(tree.source, tree.span(index).start);
        const name = tree.string(identifier.name);

        var uses = self.symbol_table.symbolUses(symbol_id);
        while (uses.next()) |use| {
            const use_span = tree.span(use);
            if (spanInside(use_span, context)) continue;

            try core.addDiagnosticFmt(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                use_span,
                "'{s}' declared on line {d} column {d} is used outside of binding context.",
                .{ name, definition_position.line, definition_position.column },
            );
        }
    }
};

fn spanInside(span: ast.Span, context: ast.Span) bool {
    return span.start >= context.start and span.end <= context.end;
}

fn offsetToLineColumn(source: []const u8, offset: u32) core.SourcePosition {
    const end = @min(@as(usize, @intCast(offset)), source.len);
    var line: usize = 1;
    var column: usize = 1;
    var index: usize = 0;

    while (index < end) : (index += 1) {
        if (source[index] == '\n') {
            line += 1;
            column = 1;
        } else {
            column += 1;
        }
    }

    return .{ .line = line, .column = column };
}
