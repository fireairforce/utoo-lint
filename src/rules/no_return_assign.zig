const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-return-assign";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NodeIndex,
) Allocator.Error!void {
    const assignment = findUnparenthesizedAssignment(tree, expression) orelse return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Return statement should not contain assignment.",
        tree.span(assignment),
    );
}

fn findUnparenthesizedAssignment(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.NodeIndex {
    if (index == .null) return null;

    switch (tree.data(index)) {
        .parenthesized_expression => return null,
        .assignment_expression => return index,
        .chain_expression => |chain| return findUnparenthesizedAssignment(tree, chain.expression),
        .binary_expression => |expression| {
            if (findUnparenthesizedAssignment(tree, expression.left)) |assignment| return assignment;
            return findUnparenthesizedAssignment(tree, expression.right);
        },
        .logical_expression => |expression| {
            if (findUnparenthesizedAssignment(tree, expression.left)) |assignment| return assignment;
            return findUnparenthesizedAssignment(tree, expression.right);
        },
        .unary_expression => |expression| return findUnparenthesizedAssignment(tree, expression.argument),
        .conditional_expression => |expression| {
            if (findUnparenthesizedAssignment(tree, expression.@"test")) |assignment| return assignment;
            if (findUnparenthesizedAssignment(tree, expression.consequent)) |assignment| return assignment;
            return findUnparenthesizedAssignment(tree, expression.alternate);
        },
        .sequence_expression => |expression| {
            for (tree.extra(expression.expressions)) |item| {
                if (findUnparenthesizedAssignment(tree, item)) |assignment| return assignment;
            }
            return null;
        },
        .call_expression => |call| {
            if (findUnparenthesizedAssignment(tree, call.callee)) |assignment| return assignment;
            for (tree.extra(call.arguments)) |argument| {
                if (findUnparenthesizedAssignment(tree, argument)) |assignment| return assignment;
            }
            return null;
        },
        .new_expression => |new| {
            if (findUnparenthesizedAssignment(tree, new.callee)) |assignment| return assignment;
            for (tree.extra(new.arguments)) |argument| {
                if (findUnparenthesizedAssignment(tree, argument)) |assignment| return assignment;
            }
            return null;
        },
        .member_expression => |member| {
            if (findUnparenthesizedAssignment(tree, member.object)) |assignment| return assignment;
            if (member.computed) return findUnparenthesizedAssignment(tree, member.property);
            return null;
        },
        else => return null,
    }
}
