const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-return-assign";

pub const Options = struct {
    style: core.NoReturnAssignStyle = .except_parens,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NodeIndex,
) Allocator.Error!void {
    try checkWithOptions(allocator, diagnostics, tree, expression, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    const assignment = findAssignment(tree, expression, options.style == .always) orelse return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Return statement should not contain assignment.",
        tree.span(assignment),
    );
}

fn findAssignment(tree: *const ast.Tree, index: ast.NodeIndex, allow_parenthesized: bool) ?ast.NodeIndex {
    if (index == .null) return null;

    switch (tree.data(index)) {
        .parenthesized_expression => |expression| {
            if (!allow_parenthesized) return null;
            return findAssignment(tree, expression.expression, allow_parenthesized);
        },
        .assignment_expression => return index,
        .chain_expression => |chain| return findAssignment(tree, chain.expression, allow_parenthesized),
        .binary_expression => |expression| {
            if (findAssignment(tree, expression.left, allow_parenthesized)) |assignment| return assignment;
            return findAssignment(tree, expression.right, allow_parenthesized);
        },
        .logical_expression => |expression| {
            if (findAssignment(tree, expression.left, allow_parenthesized)) |assignment| return assignment;
            return findAssignment(tree, expression.right, allow_parenthesized);
        },
        .unary_expression => |expression| return findAssignment(tree, expression.argument, allow_parenthesized),
        .conditional_expression => |expression| {
            if (findAssignment(tree, expression.@"test", allow_parenthesized)) |assignment| return assignment;
            if (findAssignment(tree, expression.consequent, allow_parenthesized)) |assignment| return assignment;
            return findAssignment(tree, expression.alternate, allow_parenthesized);
        },
        .sequence_expression => |expression| {
            for (tree.extra(expression.expressions)) |item| {
                if (findAssignment(tree, item, allow_parenthesized)) |assignment| return assignment;
            }
            return null;
        },
        .call_expression => |call| {
            if (findAssignment(tree, call.callee, allow_parenthesized)) |assignment| return assignment;
            for (tree.extra(call.arguments)) |argument| {
                if (findAssignment(tree, argument, allow_parenthesized)) |assignment| return assignment;
            }
            return null;
        },
        .new_expression => |new| {
            if (findAssignment(tree, new.callee, allow_parenthesized)) |assignment| return assignment;
            for (tree.extra(new.arguments)) |argument| {
                if (findAssignment(tree, argument, allow_parenthesized)) |assignment| return assignment;
            }
            return null;
        },
        .member_expression => |member| {
            if (findAssignment(tree, member.object, allow_parenthesized)) |assignment| return assignment;
            if (member.computed) return findAssignment(tree, member.property, allow_parenthesized);
            return null;
        },
        else => return null,
    }
}
