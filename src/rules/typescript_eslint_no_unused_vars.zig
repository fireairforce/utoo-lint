const parser = @import("parser");
const core = @import("../core.zig");
const no_unused_vars = @import("no_unused_vars.zig");

const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-unused-vars";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const parser.ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    react_jsx_uses_react: bool,
    react_jsx_uses_vars: bool,
    args: core.NoUnusedVarsArgs,
) Allocator.Error!void {
    try no_unused_vars.runWithOptions(allocator, diagnostics, tree, symbol_table, .{
        .rule_id = id,
        .severity = .@"error",
        .check_parameters = args != .none,
        .args_after_used = args == .after_used,
        .ignore_rest_siblings = true,
        .check_type_parameters = true,
        .react_jsx_uses_react = react_jsx_uses_react,
        .react_jsx_uses_vars = react_jsx_uses_vars,
    });
}
