const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-undef";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var iter = symbol_table.iterUnresolved();

    while (iter.next()) |entry| {
        const reference = entry.reference;
        if (reference.kind != .value) continue;
        if (tree.data(reference.node) == .jsx_identifier) continue;

        const name = tree.string(reference.name);
        if (core.isKnownGlobal(name)) continue;

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(reference.node),
            "'{s}' is not defined.",
            .{name},
        );
    }
}
