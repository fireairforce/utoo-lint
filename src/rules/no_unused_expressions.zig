const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-unused-expressions";

pub const Options = struct {
    rule_id: []const u8 = id,
    severity: core.Severity = .warning,
    allow_short_circuit: bool = false,
    allow_ternary: bool = false,
    allow_tagged_templates: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ExpressionStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkWithOptions(allocator, diagnostics, tree, statement, index, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ExpressionStatement,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (hasSideEffect(tree, statement.expression, options)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        options.severity,
        options.rule_id,
        "Expected an assignment or function call and instead saw an expression.",
        tree.span(index),
    );
}

fn hasSideEffect(tree: *const ast.Tree, index: ast.NodeIndex, options: Options) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .assignment_expression,
        .await_expression,
        .call_expression,
        .import_expression,
        .new_expression,
        .update_expression,
        .yield_expression,
        => true,

        .tagged_template_expression => options.allow_tagged_templates,

        .chain_expression => |chain| hasSideEffect(tree, chain.expression, options),
        .conditional_expression => |conditional| options.allow_ternary and
            hasSideEffect(tree, conditional.consequent, options) and
            hasSideEffect(tree, conditional.alternate, options),
        .logical_expression => |logical| options.allow_short_circuit and
            hasSideEffect(tree, logical.right, options),
        .parenthesized_expression => |parenthesized| hasSideEffect(tree, parenthesized.expression, options),
        .sequence_expression => |sequence| hasLastExpressionSideEffect(tree, sequence, options),

        else => false,
    };
}

fn hasLastExpressionSideEffect(tree: *const ast.Tree, sequence: ast.SequenceExpression, options: Options) bool {
    const expressions = tree.extra(sequence.expressions);
    if (expressions.len == 0) return false;

    return hasSideEffect(tree, expressions[expressions.len - 1], options);
}
