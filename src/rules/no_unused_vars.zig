const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-unused-vars";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var iter = symbol_table.iterSymbols();

    while (iter.next()) |entry| {
        const symbol = entry.symbol;
        const flags = symbol.flags;

        if (!isLintableSymbol(flags)) continue;
        if (flags.exported or flags.ambient) continue;
        if (flags.parameter or flags.catch_var) continue;
        if (symbol_table.isReferenced(entry.id)) continue;

        const name = tree.string(symbol.name);
        if (std.mem.startsWith(u8, name, "_")) continue;

        const decls = symbol_table.symbolDecls(entry.id);
        if (decls.len == 0) continue;

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(decls[0]),
            "'{s}' is declared but never used.",
            .{name},
        );
    }
}

fn isLintableSymbol(flags: traverser.semantic.Symbol.Flags) bool {
    return flags.inValueSpace() or
        flags.import or
        flags.type_import or
        flags.interface or
        flags.type_alias;
}

