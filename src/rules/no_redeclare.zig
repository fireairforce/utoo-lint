const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-redeclare";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var iter = symbol_table.iterSymbols();

    while (iter.next()) |entry| {
        const symbol = entry.symbol;
        if (!isLintableSymbol(symbol.flags)) continue;

        const decls = symbol_table.symbolDecls(entry.id);
        if (decls.len == 0) continue;

        const name = tree.string(symbol.name);
        if (tree.source_type == .script and symbol.scope == .root and core.isKnownGlobal(name)) {
            for (decls) |decl| {
                try core.addDiagnosticFmt(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    tree.span(decl),
                    "'{s}' is already defined as a built-in global variable.",
                    .{name},
                );
            }
            continue;
        }

        if (decls.len <= 1) continue;

        for (decls[1..]) |decl| {
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .warning,
                id,
                tree.span(decl),
                "'{s}' is already defined.",
                .{name},
            );
        }
    }
}

fn isLintableSymbol(flags: traverser.semantic.Symbol.Flags) bool {
    if (flags.ambient) return false;
    if (flags.type_import or flags.interface or flags.type_alias or flags.type_parameter) return false;
    return flags.inValueSpace() or flags.import;
}
