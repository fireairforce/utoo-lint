const parser = @import("parser");
const core = @import("../core.zig");
const no_unused_vars = @import("no_unused_vars.zig");

const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-unused-vars";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const parser.ast.Tree,
    scope_tree: traverser.semantic.ScopeTree,
    symbol_table: traverser.semantic.SymbolTable,
    react_jsx_uses_react: bool,
    check_imports: bool,
    vars: core.NoUnusedVarsVars,
    args: core.NoUnusedVarsArgs,
    caught_errors: core.NoUnusedVarsCaughtErrors,
    ignore_rest_siblings: bool,
    ignore_class_with_static_init_block: bool,
    ignore_using_declarations: bool,
    args_ignore_pattern: core.NoUnusedVarsIgnorePattern,
    caught_errors_ignore_pattern: core.NoUnusedVarsIgnorePattern,
    destructured_array_ignore_pattern: core.NoUnusedVarsIgnorePattern,
    report_used_ignore_pattern: bool,
    vars_ignore_pattern: core.NoUnusedVarsIgnorePattern,
) Allocator.Error!void {
    try no_unused_vars.runWithOptions(allocator, diagnostics, tree, scope_tree, symbol_table, .{
        .rule_id = id,
        .severity = .@"error",
        .vars = vars,
        .check_parameters = args != .none,
        .args_after_used = args == .after_used,
        .check_caught_errors = caught_errors == .all,
        .ignore_rest_siblings = ignore_rest_siblings,
        .ignore_class_with_static_init_block = ignore_class_with_static_init_block,
        .ignore_using_declarations = ignore_using_declarations,
        .check_type_parameters = true,
        .check_imports = check_imports,
        .react_jsx_uses_react = react_jsx_uses_react,
        .args_ignore_pattern = args_ignore_pattern,
        .caught_errors_ignore_pattern = caught_errors_ignore_pattern,
        .destructured_array_ignore_pattern = destructured_array_ignore_pattern,
        .report_used_ignore_pattern = report_used_ignore_pattern,
        .vars_ignore_pattern = vars_ignore_pattern,
    });
}
