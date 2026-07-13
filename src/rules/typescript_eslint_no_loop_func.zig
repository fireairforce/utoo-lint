const parser = @import("parser");
const core = @import("../core.zig");
const no_loop_func = @import("no_loop_func.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-loop-func";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    try no_loop_func.runWithId(allocator, diagnostics, tree, symbol_table, id);
}
