const parser = @import("parser");
const core = @import("../core.zig");
const no_shadow = @import("no_shadow.zig");

const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-shadow";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const parser.ast.Tree,
    scope_tree: traverser.semantic.ScopeTree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    try no_shadow.runWithOptions(allocator, diagnostics, tree, scope_tree, symbol_table, .{
        .rule_id = id,
        .severity = .@"error",
        .mode = .typescript,
    });
}
