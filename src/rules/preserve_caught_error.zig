const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "preserve-caught-error";

const SymbolId = traverser.semantic.SymbolId;
const DeclSymbolMap = std.AutoHashMap(ast.NodeIndex, SymbolId);
const ReferenceLookup = std.AutoHashMap(ast.NodeIndex, SymbolId);

pub const Options = struct {
    require_catch_parameter: bool = false,
};

const CatchContext = struct {
    index: ast.NodeIndex,
    barrier_depth: usize,
    has_parameter: bool = false,
    destructured: bool = false,
    name: []const u8 = "",
    symbol_id: SymbolId = .none,
};

const CauseInfo = union(enum) {
    none,
    unknown,
    value: ast.NodeIndex,
};

const CallLike = struct {
    callee: ast.NodeIndex,
    arguments: ast.IndexRange,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    options: Options,
) Allocator.Error!void {
    var decl_symbols = try buildDeclSymbolMap(allocator, symbol_table);
    defer decl_symbols.deinit();

    var reference_lookup = try buildReferenceLookup(allocator, symbol_table);
    defer reference_lookup.deinit();

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
        .decl_symbols = &decl_symbols,
        .reference_lookup = &reference_lookup,
        .options = options,
    };
    defer visitor.catch_stack.deinit(allocator);

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,
    decl_symbols: *const DeclSymbolMap,
    reference_lookup: *const ReferenceLookup,
    options: Options,
    catch_stack: std.ArrayList(CatchContext) = .empty,
    barrier_depth: usize = 0,

    pub fn enter_catch_clause(
        self: *Visitor,
        clause: ast.CatchClause,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        var catch_context = CatchContext{
            .index = index,
            .barrier_depth = self.barrier_depth,
        };

        if (clause.param != .null) {
            catch_context.has_parameter = true;
            if (bindingIdentifierName(ctx.tree, clause.param)) |name| {
                catch_context.name = name;
                catch_context.symbol_id = self.decl_symbols.get(clause.param) orelse .none;
            } else {
                catch_context.destructured = true;
            }
        }

        try self.catch_stack.append(self.allocator, catch_context);
        return .proceed;
    }

    pub fn exit_catch_clause(self: *Visitor, _: ast.CatchClause, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        _ = self.catch_stack.pop();
    }

    pub fn enter_function(self: *Visitor, _: ast.Function, _: ast.NodeIndex, _: *traverser.basic.Ctx) traverser.Action {
        self.barrier_depth += 1;
        return .proceed;
    }

    pub fn exit_function(self: *Visitor, _: ast.Function, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.barrier_depth -= 1;
    }

    pub fn enter_arrow_function_expression(self: *Visitor, _: ast.ArrowFunctionExpression, _: ast.NodeIndex, _: *traverser.basic.Ctx) traverser.Action {
        self.barrier_depth += 1;
        return .proceed;
    }

    pub fn exit_arrow_function_expression(self: *Visitor, _: ast.ArrowFunctionExpression, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.barrier_depth -= 1;
    }

    pub fn enter_class(self: *Visitor, _: ast.Class, _: ast.NodeIndex, _: *traverser.basic.Ctx) traverser.Action {
        self.barrier_depth += 1;
        return .proceed;
    }

    pub fn exit_class(self: *Visitor, _: ast.Class, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.barrier_depth -= 1;
    }

    pub fn enter_static_block(self: *Visitor, _: ast.StaticBlock, _: ast.NodeIndex, _: *traverser.basic.Ctx) traverser.Action {
        self.barrier_depth += 1;
        return .proceed;
    }

    pub fn exit_static_block(self: *Visitor, _: ast.StaticBlock, _: ast.NodeIndex, _: *traverser.basic.Ctx) void {
        self.barrier_depth -= 1;
    }

    pub fn enter_throw_statement(
        self: *Visitor,
        statement: ast.ThrowStatement,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const catch_context = self.currentCatch() orelse return .proceed;
        if (!self.isThrowingGlobalError(ctx.tree, statement.argument)) return .proceed;

        if (catch_context.destructured) {
            try self.addDiagnostic(ctx.tree, catch_context.index, "Re-throws cannot preserve the caught error as a part of it is being lost due to destructuring.");
            return .proceed;
        }

        if (!catch_context.has_parameter) {
            if (self.options.require_catch_parameter) {
                try self.addDiagnostic(ctx.tree, index, "The caught error is not accessible because the catch clause lacks the error parameter. Start referencing the caught error using the catch parameter.");
            }
            return .proceed;
        }

        switch (errorCause(ctx.tree, statement.argument)) {
            .unknown => return .proceed,
            .none => try self.addDiagnostic(ctx.tree, index, "There is no `cause` attached to the symptom error being thrown."),
            .value => |cause| {
                const cause_name = identifierReferenceName(ctx.tree, unwrapTransparent(ctx.tree, cause)) orelse {
                    try self.addDiagnostic(ctx.tree, cause, "The symptom error is being thrown with an incorrect `cause`.");
                    return .proceed;
                };
                if (!std.mem.eql(u8, cause_name, catch_context.name)) {
                    try self.addDiagnostic(ctx.tree, cause, "The symptom error is being thrown with an incorrect `cause`.");
                    return .proceed;
                }

                const cause_symbol = self.reference_lookup.get(unwrapTransparent(ctx.tree, cause)) orelse .none;
                if (catch_context.symbol_id != .none and cause_symbol != catch_context.symbol_id) {
                    try self.addDiagnostic(ctx.tree, index, "The caught error is being attached as `cause`, but is shadowed by a closer scoped redeclaration.");
                }
            },
        }

        return .proceed;
    }

    fn currentCatch(self: *const Visitor) ?CatchContext {
        var index = self.catch_stack.items.len;
        while (index > 0) {
            index -= 1;
            const catch_context = self.catch_stack.items[index];
            if (catch_context.barrier_depth == self.barrier_depth) return catch_context;
        }
        return null;
    }

    fn isThrowingGlobalError(self: *const Visitor, tree: *const ast.Tree, index: ast.NodeIndex) bool {
        const expression = unwrapTransparent(tree, index);
        const callee = switch (tree.data(expression)) {
            .new_expression => |new_expression| new_expression.callee,
            .call_expression => |call_expression| call_expression.callee,
            else => return false,
        };

        const callee_index = unwrapTransparent(tree, callee);
        const name = identifierReferenceName(tree, callee_index) orelse return false;
        if (!isBuiltInErrorName(name)) return false;
        return isUnresolvedReference(self.symbol_table, callee_index);
    }

    fn addDiagnostic(
        self: *Visitor,
        tree: *const ast.Tree,
        index: ast.NodeIndex,
        message: []const u8,
    ) Allocator.Error!void {
        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            message,
            tree.span(index),
        );
    }
};

fn errorCause(tree: *const ast.Tree, thrown_index: ast.NodeIndex) CauseInfo {
    const thrown = unwrapTransparent(tree, thrown_index);
    const call: CallLike = switch (tree.data(thrown)) {
        .new_expression => |new_expression| .{ .callee = new_expression.callee, .arguments = new_expression.arguments },
        .call_expression => |call_expression| .{ .callee = call_expression.callee, .arguments = call_expression.arguments },
        else => return .unknown,
    };

    const callee_name = identifierReferenceName(tree, unwrapTransparent(tree, call.callee)) orelse return .unknown;
    const options_index: usize = if (std.mem.eql(u8, callee_name, "AggregateError")) 2 else 1;
    const arguments = tree.extra(call.arguments);

    for (arguments, 0..) |argument, argument_index| {
        if (argument_index > options_index) break;
        if (tree.data(argument) == .spread_element) return .unknown;
    }

    if (arguments.len <= options_index) return .none;
    const options = unwrapTransparent(tree, arguments[options_index]);
    const object = switch (tree.data(options)) {
        .object_expression => |object| object,
        else => return .unknown,
    };

    var cause: ast.NodeIndex = .null;
    for (tree.extra(object.properties)) |property_index| {
        switch (tree.data(property_index)) {
            .spread_element => return .unknown,
            .object_property => |property| {
                const name = staticPropertyName(tree, property) orelse continue;
                if (std.mem.eql(u8, name, "cause")) cause = property.value;
            },
            else => {},
        }
    }

    if (cause == .null) return .none;
    return .{ .value = cause };
}

fn staticPropertyName(tree: *const ast.Tree, property: ast.ObjectProperty) ?[]const u8 {
    if (!property.computed) {
        return switch (tree.data(property.key)) {
            .identifier_name => |identifier| tree.string(identifier.name),
            .string_literal => |literal| tree.string(literal.value),
            else => null,
        };
    }
    return switch (tree.data(unwrapTransparent(tree, property.key))) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn buildDeclSymbolMap(
    allocator: Allocator,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!DeclSymbolMap {
    var map = DeclSymbolMap.init(allocator);
    errdefer map.deinit();

    var iter = symbol_table.iterSymbols();
    while (iter.next()) |entry| {
        for (symbol_table.symbolDecls(entry.id)) |decl| {
            try map.put(decl, entry.id);
        }
    }
    return map;
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

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isBuiltInErrorName(name: []const u8) bool {
    return std.mem.eql(u8, name, "Error") or
        std.mem.eql(u8, name, "EvalError") or
        std.mem.eql(u8, name, "RangeError") or
        std.mem.eql(u8, name, "ReferenceError") or
        std.mem.eql(u8, name, "SyntaxError") or
        std.mem.eql(u8, name, "TypeError") or
        std.mem.eql(u8, name, "URIError") or
        std.mem.eql(u8, name, "AggregateError");
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
