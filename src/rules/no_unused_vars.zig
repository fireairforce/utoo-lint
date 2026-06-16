const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-unused-vars";

const SymbolId = traverser.semantic.SymbolId;
const IgnoredDecls = std.AutoHashMap(ast.NodeIndex, void);

pub const Options = struct {
    rule_id: []const u8 = id,
    severity: core.Severity = .warning,
    check_parameters: bool = false,
    args_after_used: bool = false,
    ignore_rest_siblings: bool = false,
    check_type_parameters: bool = false,
    react_jsx_uses_react: bool = false,
    react_jsx_uses_vars: bool = true,
};

const JSXReactUsage = struct {
    pragma: []const u8 = "React",
    has_jsx: bool = false,
    has_fragment: bool = false,

    pub fn enter_jsx_opening_element(
        usage: *JSXReactUsage,
        _: ast.JSXOpeningElement,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) traverser.Action {
        usage.has_jsx = true;
        return .proceed;
    }

    pub fn enter_jsx_opening_fragment(
        usage: *JSXReactUsage,
        _: ast.JSXOpeningFragment,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) traverser.Action {
        usage.has_jsx = true;
        return .proceed;
    }

    pub fn enter_jsx_fragment(
        usage: *JSXReactUsage,
        _: ast.JSXFragment,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) traverser.Action {
        usage.has_fragment = true;
        return .proceed;
    }
};

const Parameter = struct {
    symbol_id: SymbolId,
    scope: traverser.semantic.ScopeId,
    start: u32,
    used: bool,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    try runWithOptions(allocator, diagnostics, tree, symbol_table, .{});
}

pub fn runWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    options: Options,
) Allocator.Error!void {
    var parameters: std.ArrayList(Parameter) = .empty;
    defer parameters.deinit(allocator);

    if (options.check_parameters and options.args_after_used) {
        try collectParameters(allocator, tree, symbol_table, options, &parameters);
        std.mem.sort(Parameter, parameters.items, {}, lessThanParameter);
    }

    var ignored_decls = IgnoredDecls.init(allocator);
    defer ignored_decls.deinit();

    if (options.ignore_rest_siblings) {
        var visitor = RestSiblingVisitor{ .ignored_decls = &ignored_decls };
        try traverser.basic.traverse(RestSiblingVisitor, tree, &visitor);
    }

    const jsx_react_usage = if (options.react_jsx_uses_react) collectJSXReactUsage(tree) else JSXReactUsage{};

    var iter = symbol_table.iterSymbols();

    while (iter.next()) |entry| {
        const symbol = entry.symbol;
        const flags = symbol.flags;

        if (!isLintableSymbol(flags, options)) continue;
        if (flags.exported or flags.ambient) continue;
        if (flags.parameter) {
            if (!options.check_parameters) continue;
            if (options.args_after_used and !shouldCheckParameter(entry.id, symbol.scope, parameters.items)) continue;
        }
        if (isReferenced(tree, symbol_table, entry.id, options)) continue;

        const name = tree.string(symbol.name);
        if (std.mem.startsWith(u8, name, "_")) continue;
        if (isUsedByReactJSX(name, jsx_react_usage)) continue;

        const decls = symbol_table.symbolDecls(entry.id);
        if (decls.len == 0) continue;
        if (ignored_decls.contains(decls[0])) continue;

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            options.severity,
            options.rule_id,
            tree.span(decls[0]),
            "'{s}' is declared but never used.",
            .{name},
        );
    }
}

fn isLintableSymbol(flags: traverser.semantic.Symbol.Flags, options: Options) bool {
    return flags.inValueSpace() or
        flags.catch_var or
        flags.import or
        flags.type_import or
        flags.interface or
        flags.type_alias or
        (options.check_type_parameters and flags.type_parameter);
}

fn isReferenced(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    symbol_id: SymbolId,
    options: Options,
) bool {
    if (options.react_jsx_uses_vars) return symbol_table.isReferenced(symbol_id);

    var iter = symbol_table.symbolUses(symbol_id);
    while (iter.next()) |use_node| {
        if (tree.data(use_node) != .jsx_identifier) return true;
    }
    return false;
}

fn collectParameters(
    allocator: Allocator,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    options: Options,
    parameters: *std.ArrayList(Parameter),
) Allocator.Error!void {
    var iter = symbol_table.iterSymbols();
    while (iter.next()) |entry| {
        const symbol = entry.symbol;
        if (!symbol.flags.parameter) continue;

        const decls = symbol_table.symbolDecls(entry.id);
        if (decls.len == 0) continue;

        try parameters.append(allocator, .{
            .symbol_id = entry.id,
            .scope = symbol.scope,
            .start = tree.span(decls[0]).start,
            .used = isReferenced(tree, symbol_table, entry.id, options),
        });
    }
}

fn lessThanParameter(_: void, a: Parameter, b: Parameter) bool {
    const a_scope = @intFromEnum(a.scope);
    const b_scope = @intFromEnum(b.scope);
    if (a_scope != b_scope) return a_scope < b_scope;
    return a.start < b.start;
}

fn shouldCheckParameter(
    symbol_id: SymbolId,
    scope: traverser.semantic.ScopeId,
    parameters: []const Parameter,
) bool {
    var index: ?usize = null;
    var last_used: ?usize = null;

    for (parameters, 0..) |parameter, i| {
        if (parameter.scope != scope) continue;
        if (parameter.symbol_id == symbol_id) index = i;
        if (parameter.used) last_used = i;
    }

    const current = index orelse return true;
    const last = last_used orelse return true;
    return current > last;
}

const RestSiblingVisitor = struct {
    ignored_decls: *IgnoredDecls,

    pub fn enter_object_pattern(
        self: *RestSiblingVisitor,
        pattern: ast.ObjectPattern,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (pattern.rest == .null) return .proceed;

        for (ctx.tree.extra(pattern.properties)) |property_index| {
            const property = ctx.tree.data(property_index).binding_property;
            try self.collectBinding(property.value, ctx);
        }

        return .proceed;
    }

    fn collectBinding(
        self: *RestSiblingVisitor,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!void {
        if (index == .null) return;

        switch (ctx.tree.data(index)) {
            .binding_identifier => try self.ignored_decls.put(index, {}),
            .assignment_pattern => |assignment| try self.collectBinding(assignment.left, ctx),
            .binding_rest_element => |rest| try self.collectBinding(rest.argument, ctx),
            .array_pattern => |array| {
                for (ctx.tree.extra(array.elements)) |element| {
                    try self.collectBinding(element, ctx);
                }
                try self.collectBinding(array.rest, ctx);
            },
            .object_pattern => |object| {
                for (ctx.tree.extra(object.properties)) |property_index| {
                    const property = ctx.tree.data(property_index).binding_property;
                    try self.collectBinding(property.value, ctx);
                }
                try self.collectBinding(object.rest, ctx);
            },
            else => {},
        }
    }
};

fn collectJSXReactUsage(tree: *const ast.Tree) JSXReactUsage {
    var usage = JSXReactUsage{
        .pragma = pragmaFromComments(tree) orelse "React",
    };
    traverser.basic.traverse(JSXReactUsage, tree, &usage) catch unreachable;
    return usage;
}

fn isUsedByReactJSX(name: []const u8, usage: JSXReactUsage) bool {
    return (usage.has_jsx and std.mem.eql(u8, name, usage.pragma)) or
        (usage.has_fragment and std.mem.eql(u8, name, "Fragment"));
}

fn pragmaFromComments(tree: *const ast.Tree) ?[]const u8 {
    for (tree.comments) |comment| {
        const value = tree.string(comment.value);
        const marker_index = std.mem.indexOf(u8, value, "@jsx") orelse continue;
        var cursor = marker_index + "@jsx".len;

        if (cursor >= value.len or !isWhitespace(value[cursor])) continue;
        while (cursor < value.len and isWhitespace(value[cursor])) : (cursor += 1) {}

        const start = cursor;
        while (cursor < value.len and !isWhitespace(value[cursor])) : (cursor += 1) {}
        var pragma = value[start..cursor];
        if (std.mem.indexOfScalar(u8, pragma, '.')) |dot_index| {
            pragma = pragma[0..dot_index];
        }
        if (isIdentifier(pragma)) return pragma;
    }
    return null;
}

fn isWhitespace(byte: u8) bool {
    return byte == ' ' or byte == '\t' or byte == '\n' or byte == '\r';
}

fn isIdentifier(value: []const u8) bool {
    if (value.len == 0) return false;
    if (!isIdentifierStart(value[0])) return false;
    for (value[1..]) |byte| {
        if (!isIdentifierContinue(byte)) return false;
    }
    return true;
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_' or byte == '$';
}

fn isIdentifierContinue(byte: u8) bool {
    return isIdentifierStart(byte) or std.ascii.isDigit(byte);
}
