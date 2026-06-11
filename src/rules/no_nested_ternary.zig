const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-nested-ternary";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ConditionalExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!hasNestedTernary(tree, expression)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Nested ternary expressions are not allowed.",
        tree.span(index),
    );
}

fn hasNestedTernary(tree: *const ast.Tree, expression: ast.ConditionalExpression) bool {
    return subtreeHasConditionalExpression(tree, expression.@"test") or
        subtreeHasConditionalExpression(tree, expression.consequent) or
        subtreeHasConditionalExpression(tree, expression.alternate);
}

fn subtreeHasConditionalExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    switch (tree.data(index)) {
        .conditional_expression => return true,
        inline else => |node| {
            const Node = @TypeOf(node);
            if (@typeInfo(Node) != .@"struct") return false;

            inline for (@typeInfo(Node).@"struct".fields) |field| {
                if (field.type == ast.NodeIndex) {
                    if (subtreeHasConditionalExpression(tree, @field(node, field.name))) return true;
                } else if (field.type == ast.IndexRange) {
                    const range = @field(node, field.name);
                    for (tree.extra(range)) |child| {
                        if (subtreeHasConditionalExpression(tree, child)) return true;
                    }
                }
            }
        },
    }

    return false;
}
