const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;
const SymbolId = traverser.semantic.SymbolId;
const SymbolSet = std.AutoHashMap(SymbolId, void);

pub const id = "jest/no-conditional-expect";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var callback_symbols = SymbolSet.init(allocator);
    defer callback_symbols.deinit();

    var collector = CallbackCollector{
        .symbol_table = symbol_table,
        .callback_symbols = &callback_symbols,
    };
    try traverser.basic.traverse(CallbackCollector, tree, &collector);

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
        .callback_symbols = &callback_symbols,
    };
    defer visitor.function_callback_stack.deinit(allocator);
    defer visitor.conditional_stack.deinit(allocator);

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const CallbackCollector = struct {
    symbol_table: traverser.semantic.SymbolTable,
    callback_symbols: *SymbolSet,

    pub fn enter_call_expression(
        self: *CallbackCollector,
        call: ast.CallExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (!isTestCall(ctx.tree, call)) return .proceed;

        const arguments = ctx.tree.extra(call.arguments);
        if (arguments.len < 2) return .proceed;

        for (arguments[1..]) |argument| {
            const identifier = unwrapTransparent(ctx.tree, argument);
            switch (ctx.tree.data(identifier)) {
                .identifier_reference => {},
                else => continue,
            }

            const reference_id = self.symbol_table.model.referenceOf(identifier) orelse continue;
            const symbol_id = self.symbol_table.referenceSymbol(reference_id);
            if (symbol_id != .none) try self.callback_symbols.put(symbol_id, {});
        }

        return .proceed;
    }
};

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,
    callback_symbols: *const SymbolSet,
    function_callback_stack: std.ArrayList(bool) = .empty,
    conditional_stack: std.ArrayList(ast.NodeIndex) = .empty,
    test_call_depth: usize = 0,
    callback_function_depth: usize = 0,
    promise_catch_depth: usize = 0,

    pub fn enter_function(
        self: *Visitor,
        function: ast.Function,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const parent = ctx.path.ancestor(1) orelse .null;
        try self.enterFunction(functionSymbol(ctx.tree, self.symbol_table, index, parent, function.id));
        return .proceed;
    }

    pub fn exit_function(self: *Visitor, _: ast.Function, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.exitFunction();
    }

    pub fn enter_arrow_function_expression(
        self: *Visitor,
        _: ast.ArrowFunctionExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const parent = ctx.path.ancestor(1) orelse .null;
        try self.enterFunction(functionSymbol(ctx.tree, self.symbol_table, index, parent, .null));
        return .proceed;
    }

    pub fn exit_arrow_function_expression(
        self: *Visitor,
        _: ast.ArrowFunctionExpression,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) void {
        self.exitFunction();
    }

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (isTestCall(ctx.tree, call)) self.test_call_depth += 1;
        if (isCatchCall(ctx.tree, call)) self.promise_catch_depth += 1;

        if (isExpectCall(ctx.tree, call) and
            ((self.inTestCase() and self.conditional_stack.items.len > 0) or self.promise_catch_depth > 0))
        {
            try self.report(ctx.tree, index);
        }

        return .proceed;
    }

    pub fn exit_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) void {
        if (isTestCall(ctx.tree, call)) self.test_call_depth -= 1;
        if (isCatchCall(ctx.tree, call)) self.promise_catch_depth -= 1;
    }

    pub fn enter_catch_clause(self: *Visitor, _: ast.CatchClause, index: ast.NodeIndex, _: *traverser.basic.Ctx) Allocator.Error!traverser.Action {
        return self.enterConditional(index);
    }

    pub fn exit_catch_clause(self: *Visitor, _: ast.CatchClause, index: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.exitConditional(index);
    }

    pub fn enter_if_statement(self: *Visitor, _: ast.IfStatement, index: ast.NodeIndex, _: *traverser.basic.Ctx) Allocator.Error!traverser.Action {
        return self.enterConditional(index);
    }

    pub fn exit_if_statement(self: *Visitor, _: ast.IfStatement, index: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.exitConditional(index);
    }

    pub fn enter_switch_statement(self: *Visitor, _: ast.SwitchStatement, index: ast.NodeIndex, _: *traverser.basic.Ctx) Allocator.Error!traverser.Action {
        return self.enterConditional(index);
    }

    pub fn exit_switch_statement(self: *Visitor, _: ast.SwitchStatement, index: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.exitConditional(index);
    }

    pub fn enter_conditional_expression(self: *Visitor, _: ast.ConditionalExpression, index: ast.NodeIndex, _: *traverser.basic.Ctx) Allocator.Error!traverser.Action {
        return self.enterConditional(index);
    }

    pub fn exit_conditional_expression(self: *Visitor, _: ast.ConditionalExpression, index: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.exitConditional(index);
    }

    pub fn enter_logical_expression(self: *Visitor, _: ast.LogicalExpression, index: ast.NodeIndex, _: *traverser.basic.Ctx) Allocator.Error!traverser.Action {
        return self.enterConditional(index);
    }

    pub fn exit_logical_expression(self: *Visitor, _: ast.LogicalExpression, index: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.exitConditional(index);
    }

    fn enterFunction(self: *Visitor, symbol_id: ?SymbolId) Allocator.Error!void {
        const is_callback = if (symbol_id) |symbol|
            symbol != .none and self.callback_symbols.contains(symbol)
        else
            false;
        try self.function_callback_stack.append(self.allocator, is_callback);
        if (is_callback) self.callback_function_depth += 1;
    }

    fn exitFunction(self: *Visitor) void {
        if (self.function_callback_stack.pop()) |was_callback| {
            if (was_callback) self.callback_function_depth -= 1;
        }
    }

    fn enterConditional(self: *Visitor, index: ast.NodeIndex) Allocator.Error!traverser.Action {
        if (self.inTestCase()) try self.conditional_stack.append(self.allocator, index);
        return .proceed;
    }

    fn exitConditional(self: *Visitor, index: ast.NodeIndex) void {
        if (self.conditional_stack.items.len == 0) return;
        if (self.conditional_stack.items[self.conditional_stack.items.len - 1] == index) {
            _ = self.conditional_stack.pop();
        }
    }

    fn inTestCase(self: *const Visitor) bool {
        return self.test_call_depth > 0 or self.callback_function_depth > 0;
    }

    fn report(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            "Avoid calling `expect` conditionally.",
            tree.span(index),
        );
    }
};

fn functionSymbol(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
    parent: ast.NodeIndex,
    id_node: ast.NodeIndex,
) ?SymbolId {
    if (id_node != .null) return symbol_table.symbolOf(id_node);

    return switch (tree.data(parent)) {
        .variable_declarator => |declarator| if (declarator.init == index) symbol_table.symbolOf(declarator.id) else null,
        else => null,
    };
}

fn isTestCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const source = nodeSource(tree, call.callee);
    const roots = [_][]const u8{ "test", "xtest", "it", "fit", "xit" };

    for (roots) |root| {
        if (!std.mem.startsWith(u8, source, root)) continue;
        if (source.len == root.len) return true;
        return switch (source[root.len]) {
            '.', '[', '(' => true,
            else => false,
        };
    }
    return false;
}

fn isCatchCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    const name = propertyName(tree, member) orelse return false;
    return std.mem.eql(u8, name, "catch");
}

fn isExpectCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const name = identifierReferenceName(tree, call.callee) orelse return false;
    return std.mem.eql(u8, name, "expect");
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn propertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;
    return if (member.computed)
        switch (tree.data(member.property)) {
            .string_literal => |literal| tree.string(literal.value),
            else => null,
        }
    else switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
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

fn nodeSource(tree: *const ast.Tree, index: ast.NodeIndex) []const u8 {
    const span = tree.span(index);
    if (span.start >= span.end or span.end > tree.source.len) return "";
    return std.mem.trim(u8, tree.source[span.start..span.end], " \t\r\n");
}
