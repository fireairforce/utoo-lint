const parser = @import("parser");
const core = @import("../core.zig");
const dot_notation = @import("dot_notation.zig");

const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/dot-notation";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const parser.ast.Tree,
    member: parser.ast.MemberExpression,
    index: parser.ast.NodeIndex,
) Allocator.Error!void {
    try checkWithOptions(allocator, diagnostics, tree, member, index, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const parser.ast.Tree,
    member: parser.ast.MemberExpression,
    index: parser.ast.NodeIndex,
    options: dot_notation.Options,
) Allocator.Error!void {
    try dot_notation.checkWithOptions(allocator, diagnostics, tree, member, index, .{
        .rule_id = id,
        .severity = .@"error",
        .allow_keywords = options.allow_keywords,
        .allow_pattern = options.allow_pattern,
    });
}
