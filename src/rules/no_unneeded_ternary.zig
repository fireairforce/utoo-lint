const parser = @import("parser");
const core = @import("../core.zig");
const std = @import("std");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-unneeded-ternary";

pub const Options = struct {
    default_assignment: bool = true,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ConditionalExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    return checkWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ConditionalExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (isUnneededBooleanTernary(tree, expression)) {
        const replacement = try booleanTernaryReplacement(allocator, tree, expression, index);
        defer if (replacement) |value| allocator.free(value);

        if (replacement) |value| {
            try core.addDiagnosticWithFix(
                allocator,
                diagnostics,
                .warning,
                id,
                "Unnecessary use of boolean literals in conditional expression.",
                tree.span(index),
                .{ .span = tree.span(index), .replacement = value },
            );
        } else {
            try core.addDiagnostic(
                allocator,
                diagnostics,
                .warning,
                id,
                "Unnecessary use of boolean literals in conditional expression.",
                tree.span(index),
            );
        }
        return;
    }

    if (options.default_assignment or !isDefaultAssignment(tree, expression)) return;

    const replacement = try defaultAssignmentReplacement(allocator, tree, expression);
    defer if (replacement) |value| allocator.free(value);

    if (replacement) |value| {
        try core.addDiagnosticWithFix(
            allocator,
            diagnostics,
            .warning,
            id,
            "Unnecessary use of conditional expression for default assignment.",
            tree.span(index),
            .{ .span = tree.span(index), .replacement = value },
        );
    } else {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Unnecessary use of conditional expression for default assignment.",
            tree.span(index),
        );
    }
}

fn booleanTernaryReplacement(
    allocator: Allocator,
    tree: *const ast.Tree,
    expression: ast.ConditionalExpression,
    index: ast.NodeIndex,
) Allocator.Error!?[]u8 {
    const consequent = booleanLiteralValue(tree, expression.consequent).?;
    const alternate = booleanLiteralValue(tree, expression.alternate).?;
    const expression_span = tree.span(index);

    if (consequent == alternate) {
        if (identifierReferenceName(tree, expression.@"test") == null or hasCommentInside(tree, expression_span)) return null;
        return @as(?[]u8, try allocator.dupe(u8, if (consequent) "true" else "false"));
    }

    const test_span = tree.span(expression.@"test");
    if (hasCommentBetween(tree, test_span.end, expression_span.end)) return null;

    if (alternate) return @as(?[]u8, try invertExpression(allocator, tree, expression.@"test"));
    if (isBooleanExpression(tree, expression.@"test")) {
        return @as(?[]u8, try allocator.dupe(u8, sourceForSpan(tree, test_span)));
    }

    const inverted = try invertExpression(allocator, tree, expression.@"test");
    defer allocator.free(inverted);
    return @as(?[]u8, try std.fmt.allocPrint(allocator, "!{s}", .{inverted}));
}

fn defaultAssignmentReplacement(
    allocator: Allocator,
    tree: *const ast.Tree,
    expression: ast.ConditionalExpression,
) Allocator.Error!?[]u8 {
    const test_span = tree.span(expression.@"test");
    const alternate_span = tree.span(expression.alternate);
    if (hasCommentBetween(tree, test_span.end, alternate_span.start)) return null;

    const test_text = sourceForSpan(tree, test_span);
    const alternate_text = sourceForSpan(tree, alternate_span);
    if (alternateNeedsParentheses(tree, expression.alternate)) {
        return @as(?[]u8, try std.fmt.allocPrint(allocator, "{s} || ({s})", .{ test_text, alternate_text }));
    }
    return @as(?[]u8, try std.fmt.allocPrint(allocator, "{s} || {s}", .{ test_text, alternate_text }));
}

fn invertExpression(allocator: Allocator, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error![]u8 {
    const span = tree.span(index);
    if (tree.data(index) == .binary_expression) {
        const binary = tree.data(index).binary_expression;
        if (inverseOperator(binary.operator)) |inverse| {
            const left_span = tree.span(binary.left);
            const right_span = tree.span(binary.right);
            if (!hasCommentBetween(tree, left_span.end, right_span.start)) {
                const between = sourceForRange(tree, left_span.end, right_span.start);
                const operator = binary.operator.toString();
                if (std.mem.indexOf(u8, between, operator)) |relative_start| {
                    const operator_start = left_span.end + @as(u32, @intCast(relative_start));
                    const operator_end = operator_start + @as(u32, @intCast(operator.len));
                    return std.fmt.allocPrint(
                        allocator,
                        "{s}{s}{s}",
                        .{
                            sourceForRange(tree, span.start, operator_start),
                            inverse,
                            sourceForRange(tree, operator_end, span.end),
                        },
                    );
                }
            }
        }
    }

    const text = sourceForSpan(tree, span);
    if (unaryNegationNeedsParentheses(tree, index)) {
        return std.fmt.allocPrint(allocator, "!({s})", .{text});
    }
    return std.fmt.allocPrint(allocator, "!{s}", .{text});
}

fn inverseOperator(operator: ast.BinaryOperator) ?[]const u8 {
    return switch (operator) {
        .equal => "!=",
        .not_equal => "==",
        .strict_equal => "!==",
        .strict_not_equal => "===",
        else => null,
    };
}

fn isBooleanExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .binary_expression => |binary| switch (binary.operator) {
            .equal,
            .not_equal,
            .strict_equal,
            .strict_not_equal,
            .less_than,
            .less_than_or_equal,
            .greater_than,
            .greater_than_or_equal,
            .in,
            .instanceof,
            => true,
            else => false,
        },
        .unary_expression => |unary| unary.operator == .logical_not,
        else => false,
    };
}

fn unaryNegationNeedsParentheses(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (tree.data(index) == .parenthesized_expression) return false;
    return switch (tree.data(index)) {
        .sequence_expression,
        .arrow_function_expression,
        .yield_expression,
        .assignment_expression,
        .conditional_expression,
        .logical_expression,
        .binary_expression,
        .ts_as_expression,
        .ts_satisfies_expression,
        .ts_type_assertion,
        => true,
        else => false,
    };
}

fn alternateNeedsParentheses(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (tree.data(index) == .parenthesized_expression) return false;
    return switch (tree.data(index)) {
        .sequence_expression,
        .arrow_function_expression,
        .yield_expression,
        .assignment_expression,
        .conditional_expression,
        .ts_as_expression,
        .ts_satisfies_expression,
        .ts_type_assertion,
        => true,
        .logical_expression => |logical| logical.operator == .nullish_coalescing,
        else => false,
    };
}

fn hasCommentInside(tree: *const ast.Tree, span: ast.Span) bool {
    return hasCommentBetween(tree, span.start, span.end);
}

fn hasCommentBetween(tree: *const ast.Tree, start: u32, end: u32) bool {
    for (tree.comments) |comment| {
        if (comment.span.end <= start) continue;
        if (comment.span.start >= end) break;
        return true;
    }
    return false;
}

fn sourceForSpan(tree: *const ast.Tree, span: ast.Span) []const u8 {
    return sourceForRange(tree, span.start, span.end);
}

fn sourceForRange(tree: *const ast.Tree, start: u32, end: u32) []const u8 {
    return tree.source[@intCast(start)..@intCast(end)];
}

fn isUnneededBooleanTernary(tree: *const ast.Tree, expression: ast.ConditionalExpression) bool {
    _ = booleanLiteralValue(tree, expression.consequent) orelse return false;
    _ = booleanLiteralValue(tree, expression.alternate) orelse return false;
    return true;
}

fn isDefaultAssignment(tree: *const ast.Tree, expression: ast.ConditionalExpression) bool {
    const test_name = identifierReferenceName(tree, expression.@"test") orelse return false;
    const consequent_name = identifierReferenceName(tree, expression.consequent) orelse return false;
    return std.mem.eql(u8, test_name, consequent_name);
}

fn booleanLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?bool {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .boolean_literal => |literal| literal.value,
        else => null,
    };
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;

    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |chain| current = chain.expression,
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            else => return current,
        }
    }

    return current;
}
