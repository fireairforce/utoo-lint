const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-empty-pattern";

pub const Options = struct {
    allow_object_patterns_as_parameters: bool = false,
};

pub fn checkObjectPattern(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    pattern: ast.ObjectPattern,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkObjectPatternWithOptions(allocator, diagnostics, tree, pattern, index, null, null, .{});
}

pub fn checkObjectPatternWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    pattern: ast.ObjectPattern,
    index: ast.NodeIndex,
    parent_index: ?ast.NodeIndex,
    grandparent_index: ?ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (pattern.properties.len > 0 or pattern.rest != .null) return;
    if (options.allow_object_patterns_as_parameters and isAllowedObjectParameter(tree, index, parent_index, grandparent_index)) return;

    try addDiagnostic(allocator, diagnostics, tree, index, "object");
}

pub fn checkArrayPattern(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    pattern: ast.ArrayPattern,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (pattern.elements.len > 0 or pattern.rest != .null) return;

    try addDiagnostic(allocator, diagnostics, tree, index, "array");
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    pattern_type: []const u8,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Unexpected empty {s} pattern.",
        .{pattern_type},
    );
}

fn isAllowedObjectParameter(
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    parent_index: ?ast.NodeIndex,
    grandparent_index: ?ast.NodeIndex,
) bool {
    const parent = parent_index orelse return false;
    return switch (tree.data(parent)) {
        .formal_parameter => |parameter| parameter.pattern == index,
        .assignment_pattern => |assignment| blk: {
            if (assignment.left != index or !isEmptyObjectExpression(tree, assignment.right)) break :blk false;
            const grandparent = grandparent_index orelse break :blk false;
            break :blk switch (tree.data(grandparent)) {
                .formal_parameter => |parameter| parameter.pattern == parent,
                else => false,
            };
        },
        else => false,
    };
}

fn isEmptyObjectExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .object_expression => |expression| expression.properties.len == 0,
        else => false,
    };
}
