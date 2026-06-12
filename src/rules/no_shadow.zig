const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-shadow";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    scope_tree: traverser.semantic.ScopeTree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var iter = symbol_table.iterSymbols();

    while (iter.next()) |entry| {
        const symbol = entry.symbol;
        if (!isLintableSymbol(symbol.flags)) continue;
        if (symbol.scope == .root or symbol.scope == .module) continue;

        const name = tree.string(symbol.name);
        const shadowed_id = findShadowedSymbol(scope_tree, symbol_table, symbol.scope, name, entry.id) orelse continue;
        const decls = symbol_table.symbolDecls(entry.id);
        const shadowed_decls = symbol_table.symbolDecls(shadowed_id);
        if (decls.len == 0 or shadowed_decls.len == 0) continue;

        const shadowed_position = offsetToLineColumn(tree.source, tree.span(shadowed_decls[0]).start);
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
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
) ?traverser.semantic.SymbolId {
    var current = scope_tree.getScope(scope).parent;
    while (current != .none) {
        if (symbol_table.findInScope(current, name)) |candidate_id| {
            if (candidate_id != self_id and isLintableSymbol(symbol_table.getSymbol(candidate_id).flags)) {
                return candidate_id;
            }
        }
        current = scope_tree.getScope(current).parent;
    }
    return null;
}

fn isLintableSymbol(flags: traverser.semantic.Symbol.Flags) bool {
    if (flags.ambient) return false;
    if (flags.type_import or flags.interface or flags.type_alias or flags.type_parameter) return false;
    return flags.inValueSpace() or flags.import;
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
