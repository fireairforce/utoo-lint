const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-explicit-any";

pub const Options = struct {
    fix_to_unknown: bool = false,
    ignore_rest_args: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    ctx: *parser.traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (options.ignore_rest_args and isRestArgumentType(tree, ctx)) return;
    const span = tree.span(index);
    const fixes: []const core.Fix = if (options.fix_to_unknown) &.{.{ .span = span, .replacement = "unknown" }} else &.{};
    try core.addDiagnosticWithFixesAndSuggestions(allocator, diagnostics, .warning, id, "Unexpected any. Specify a different type.", span, fixes, &.{
        .{
            .message = "Use `unknown` instead, this will force you to explicitly, and safely assert the type is correct.",
            .fixes = &.{.{ .span = span, .replacement = "unknown" }},
        },
        .{
            .message = "Use `never` instead, this is useful when instantiating generic type parameters that you don't need to know the type of.",
            .fixes = &.{.{ .span = span, .replacement = "never" }},
        },
    });
}

fn isRestArgumentType(tree: *const ast.Tree, ctx: *parser.traverser.basic.Ctx) bool {
    // ESLint omits parenthesized types from this ancestry. FormalParameters is
    // an extra Yuku wrapper; verify its rest slot to exclude destructuring.
    var ancestors: [5]ast.NodeIndex = @splat(.null);
    var count: usize = 0;
    var depth: usize = 1;
    while (count < ancestors.len) : (depth += 1) {
        const ancestor = ctx.path.ancestor(depth) orelse break;
        if (tree.data(ancestor) == .ts_parenthesized_type) continue;
        ancestors[count] = ancestor;
        count += 1;
    }
    if (isFunctionRest(tree, ancestors[2], ancestors[3])) return true;
    if (!isFunctionRest(tree, ancestors[3], ancestors[4]) or ancestors[1] == .null) return false;
    return switch (tree.data(ancestors[1])) {
        .ts_type_operator => |operator| operator.operator == .readonly,
        .ts_type_reference => |reference| switch (tree.data(reference.type_name)) {
            .identifier_reference => |name| std.mem.eql(u8, tree.string(name.name), "Array") or std.mem.eql(u8, tree.string(name.name), "ReadonlyArray"),
            else => false,
        },
        else => false,
    };
}

fn isFunctionRest(tree: *const ast.Tree, rest: ast.NodeIndex, parent: ast.NodeIndex) bool {
    if (rest == .null or parent == .null or tree.data(rest) != .binding_rest_element) return false;
    return switch (tree.data(parent)) {
        .formal_parameters => |parameters| parameters.rest == rest,
        else => false,
    };
}
