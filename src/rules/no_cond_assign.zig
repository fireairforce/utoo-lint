const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-cond-assign";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NodeIndex,
) Allocator.Error!void {
    if (findAmbiguousAssignment(tree, expression)) |assignment| {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Expected a conditional expression and instead saw an assignment.",
            tree.span(assignment),
        );
    }
}

fn findAmbiguousAssignment(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.NodeIndex {
    if (index == .null) return null;

    switch (tree.data(index)) {
        .parenthesized_expression => return null,
        .assignment_expression => return index,
        .chain_expression => |chain| return findAmbiguousAssignment(tree, chain.expression),
        .binary_expression => |expression| {
            if (findAmbiguousAssignment(tree, expression.left)) |assignment| return assignment;
            return findAmbiguousAssignment(tree, expression.right);
        },
        .logical_expression => |expression| {
            if (findAmbiguousAssignment(tree, expression.left)) |assignment| return assignment;
            return findAmbiguousAssignment(tree, expression.right);
        },
        .unary_expression => |expression| return findAmbiguousAssignment(tree, expression.argument),
        .conditional_expression => |expression| {
            if (findAmbiguousAssignment(tree, expression.@"test")) |assignment| return assignment;
            if (findAmbiguousAssignment(tree, expression.consequent)) |assignment| return assignment;
            return findAmbiguousAssignment(tree, expression.alternate);
        },
        .sequence_expression => |expression| {
            for (tree.extra(expression.expressions)) |item| {
                if (findAmbiguousAssignment(tree, item)) |assignment| return assignment;
            }
            return null;
        },
        .call_expression => |call| {
            if (findAmbiguousAssignment(tree, call.callee)) |assignment| return assignment;
            for (tree.extra(call.arguments)) |argument| {
                if (findAmbiguousAssignment(tree, argument)) |assignment| return assignment;
            }
            return null;
        },
        .member_expression => |member| {
            if (findAmbiguousAssignment(tree, member.object)) |assignment| return assignment;
            if (member.computed) return findAmbiguousAssignment(tree, member.property);
            return null;
        },
        else => return null,
    }
}
