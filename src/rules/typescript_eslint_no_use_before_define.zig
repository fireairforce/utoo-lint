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
    scope_tree: traverser.semantic.ScopeTree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    try runWithOptions(allocator, diagnostics, tree, scope_tree, symbol_table, .{
        .check_functions = false,
        .check_classes = true,
    });
}

pub fn runWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const parser.ast.Tree,
    scope_tree: traverser.semantic.ScopeTree,
    symbol_table: traverser.semantic.SymbolTable,
    options: no_use_before_define.Options,
) Allocator.Error!void {
    try no_use_before_define.runWithOptions(allocator, diagnostics, tree, scope_tree, symbol_table, .{
        .rule_id = id,
        .severity = .@"error",
        .check_functions = options.check_functions,
        .check_classes = options.check_classes,
        .check_variables = options.check_variables,
        .check_type_references = options.check_type_references,
        .check_typedefs = options.check_typedefs,
        .check_enums = options.check_enums,
        .allow_named_exports = options.allow_named_exports,
    });
}
