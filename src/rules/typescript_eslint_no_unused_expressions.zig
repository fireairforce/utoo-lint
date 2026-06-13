const parser = @import("parser");
const core = @import("../core.zig");
const no_unused_expressions = @import("no_unused_expressions.zig");

const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-unused-expressions";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const parser.ast.Tree,
    statement: parser.ast.ExpressionStatement,
    index: parser.ast.NodeIndex,
) Allocator.Error!void {
    try no_unused_expressions.checkWithOptions(allocator, diagnostics, tree, statement, index, .{
        .rule_id = id,
        .severity = .@"error",
        .allow_short_circuit = true,
        .allow_ternary = true,
        .allow_tagged_templates = true,
    });
}
