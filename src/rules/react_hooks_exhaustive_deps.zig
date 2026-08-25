const parser = @import("parser");
const core = @import("../core.zig");
const exhaustive_deps = @import("alipay_ant_exhaustive_deps.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "react-hooks/exhaustive-deps";

pub fn runWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    additional_hooks: core.ReactHooksAdditionalHooksPattern,
) Allocator.Error!void {
    try exhaustive_deps.runWithOptions(allocator, diagnostics, tree, symbol_table, .{
        .rule_id = id,
        .additional_hooks = additional_hooks,
        .report_unnecessary_dependencies = true,
        .report_unstable_dependencies = true,
    });
}
