const parser = @import("parser");
const core = @import("../core.zig");
const no_redeclare = @import("no_redeclare.zig");

const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-redeclare";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const parser.ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    ignore_declaration_merge: bool,
) Allocator.Error!void {
    try no_redeclare.runWithOptions(allocator, diagnostics, tree, symbol_table, .{
        .rule_id = id,
        .severity = .@"error",
        .mode = .typescript,
        .ignore_declaration_merge = ignore_declaration_merge,
    });
}
