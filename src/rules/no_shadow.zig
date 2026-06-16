const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-shadow";

pub const Options = struct {
    rule_id: []const u8 = id,
    severity: core.Severity = .warning,
    mode: Mode = .javascript,
    allow: core.NoShadowAllowNames = .{},
    builtin_globals: bool = false,
};

pub const Mode = enum {
    javascript,
    typescript,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    scope_tree: traverser.semantic.ScopeTree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    try runWithOptions(allocator, diagnostics, tree, scope_tree, symbol_table, .{});
}

pub fn runWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    scope_tree: traverser.semantic.ScopeTree,
    symbol_table: traverser.semantic.SymbolTable,
    options: Options,
) Allocator.Error!void {
    var iter = symbol_table.iterSymbols();

    while (iter.next()) |entry| {
        const symbol = entry.symbol;
        if (!isLintableSymbol(symbol.flags, options)) continue;
        if (symbol.scope == .root or symbol.scope == .module) continue;

        const name = tree.string(symbol.name);
        if (options.allow.contains(name)) continue;

        const decls = symbol_table.symbolDecls(entry.id);
        if (decls.len == 0) continue;

        if (options.builtin_globals and core.isKnownGlobal(name)) {
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                options.severity,
                options.rule_id,
                tree.span(decls[0]),
                "'{s}' is already a global variable.",
                .{name},
            );
            continue;
        }

        const shadowed_id = findShadowedSymbol(scope_tree, symbol_table, symbol.scope, name, entry.id, symbol.flags, options) orelse continue;
        const shadowed_decls = symbol_table.symbolDecls(shadowed_id);
        if (shadowed_decls.len == 0) continue;

        const shadowed_position = offsetToLineColumn(tree.source, tree.span(shadowed_decls[0]).start);
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            options.severity,
            options.rule_id,
            tree.span(decls[0]),
            "'{s}' is already declared in the upper scope on line {d} column {d}.",
            .{ name, shadowed_position.line, shadowed_position.column },
        );
    }
}

fn findShadowedSymbol(
    scope_tree: traverser.semantic.ScopeTree,
    symbol_table: traverser.semantic.SymbolTable,
    scope: traverser.semantic.ScopeId,
    name: []const u8,
    self_id: traverser.semantic.SymbolId,
    self_flags: traverser.semantic.Symbol.Flags,
    options: Options,
) ?traverser.semantic.SymbolId {
    var current = scope_tree.getScope(scope).parent;
    while (current != .none) {
        if (symbol_table.findInScope(current, name)) |candidate_id| {
            const candidate_flags = symbol_table.getSymbol(candidate_id).flags;
            if (candidate_id != self_id and isLintableSymbol(candidate_flags, options) and !isAllowedTypescriptShadow(self_flags, candidate_flags, options)) {
                return candidate_id;
            }
        }
        current = scope_tree.getScope(current).parent;
    }
    return null;
}

fn isLintableSymbol(flags: traverser.semantic.Symbol.Flags, options: Options) bool {
    if (options.mode == .typescript) {
        return flags.inValueSpace() or
            flags.import or
            flags.type_import or
            flags.interface or
            flags.type_alias or
            flags.type_parameter or
            flags.namespace_module;
    }

    if (flags.ambient) return false;
    if (flags.type_import or flags.interface or flags.type_alias or flags.type_parameter) return false;
    return flags.inValueSpace() or flags.import;
}

fn isAllowedTypescriptShadow(
    self_flags: traverser.semantic.Symbol.Flags,
    candidate_flags: traverser.semantic.Symbol.Flags,
    options: Options,
) bool {
    if (options.mode != .typescript) return false;
    return (self_flags.interface and candidate_flags.class) or
        (self_flags.class and candidate_flags.interface);
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
