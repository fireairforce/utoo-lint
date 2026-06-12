const parser = @import("parser");
const core = @import("../core.zig");
const no_use_before_define = @import("no_use_before_define.zig");

const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-use-before-define";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const parser.ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    try no_use_before_define.runWithOptions(allocator, diagnostics, tree, symbol_table, .{
        .rule_id = id,
        .severity = .@"error",
        .check_functions = false,
        .check_classes = true,
    });
}
