const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "yoda";

pub const Style = enum {
    never,
    always,
};

pub const Options = struct {
    style: Style = .never,
    only_equality: bool = false,
    except_range: bool = false,
    parent: ast.NodeIndex = .null,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkWithStyle(allocator, diagnostics, tree, expression, index, .never);
}

pub fn checkWithStyle(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
    style: Style,
) Allocator.Error!void {
    return checkWithOptions(allocator, diagnostics, tree, expression, index, .{ .style = style });
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (!isComparisonOperator(expression.operator)) return;
    if (options.only_equality and !isEqualityOperator(expression.operator)) return;
    if (options.except_range and isRangeComparison(tree, expression, index, options.parent)) return;

    const left_literal = isLiteralLike(tree, expression.left);
    const right_literal = isLiteralLike(tree, expression.right);
    if (hasExpectedYodaStyle(options.style, left_literal, right_literal)) return;

    const fix = try buildFix(allocator, tree, expression, index);
    defer if (fix) |value| allocator.free(value.replacement);

    if (fix) |value| {
        try core.addDiagnosticWithFix(
            allocator,
            diagnostics,
            .warning,
            id,
            message(options.style),
            tree.span(index),
            value,
        );
    } else {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            message(options.style),
            tree.span(index),
        );
    }
}

fn buildFix(
    allocator: Allocator,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!?core.Fix {
    const operator_span = findOperatorSpan(tree, expression) orelse return null;
    const expression_span = tree.span(index);
    const left_span = tree.span(expression.left);
    const right_span = tree.span(expression.right);
    const operator = flippedOperator(expression.operator);
    const left_text = sourceForRange(tree, expression_span.start, left_span.end);
    const right_text = sourceForRange(tree, right_span.start, expression_span.end);
    const before_expression = tree.source[0..@intCast(expression_span.start)];
    const after_expression = tree.source[@intCast(expression_span.end)..];
    const prefix = if (needsOperandPrefix(tree, expression.right, before_expression, right_text)) " " else "";
    const suffix = if (needsOperandSuffix(tree, expression.left, left_text, after_expression)) " " else "";

    return .{
        .span = expression_span,
        .replacement = try std.fmt.allocPrint(
            allocator,
            "{s}{s}{s}{s}{s}{s}{s}",
            .{
                prefix,
                right_text,
                sourceForRange(tree, left_span.end, operator_span.start),
                operator,
                sourceForRange(tree, operator_span.end, right_span.start),
                left_text,
                suffix,
            },
        ),
    };
}

fn needsOperandPrefix(
    tree: *const ast.Tree,
    operand: ast.NodeIndex,
    before: []const u8,
    operand_text: []const u8,
) bool {
    if (needsTokenSeparator(before, operand_text)) return true;
    return tree.data(operand) == .regexp_literal and
        before.len > 0 and
        isIdentifierByte(before[before.len - 1]);
}

fn needsOperandSuffix(
    tree: *const ast.Tree,
    operand: ast.NodeIndex,
    operand_text: []const u8,
    after: []const u8,
) bool {
    if (needsTokenSeparator(operand_text, after)) return true;
    return tree.data(operand) == .regexp_literal and
        after.len > 0 and
        isIdentifierByte(after[0]);
}

fn needsTokenSeparator(left: []const u8, right: []const u8) bool {
    if (left.len == 0 or right.len == 0) return false;
    const left_byte = left[left.len - 1];
    const right_byte = right[0];
    if (std.ascii.isWhitespace(left_byte) or std.ascii.isWhitespace(right_byte)) return false;

    if (isIdentifierByte(left_byte) and isIdentifierByte(right_byte)) return true;
    if (left_byte == '+' and right_byte == '+') return true;
    if (left_byte == '-' and right_byte == '-') return true;
    return left_byte == '/' and (right_byte == '/' or right_byte == '*');
}

fn isIdentifierByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '$' or byte >= 0x80;
}

fn findOperatorSpan(tree: *const ast.Tree, expression: ast.BinaryExpression) ?ast.Span {
    const left_end = tree.span(expression.left).end;
    const right_start = tree.span(expression.right).start;
    const operator = expression.operator.toString();
    const between = sourceForRange(tree, left_end, right_start);

    var search_start: usize = 0;
    while (std.mem.indexOfPos(u8, between, search_start, operator)) |relative| {
        const start = left_end + @as(u32, @intCast(relative));
        const end = start + @as(u32, @intCast(operator.len));
        if (!hasCommentAt(tree, start)) return .{ .start = start, .end = end };
        search_start = relative + operator.len;
    }
    return null;
}

fn hasCommentAt(tree: *const ast.Tree, offset: u32) bool {
    for (tree.comments) |comment| {
        if (comment.span.end <= offset) continue;
        if (comment.span.start > offset) break;
        return true;
    }
    return false;
}

fn flippedOperator(operator: ast.BinaryOperator) []const u8 {
    return switch (operator) {
        .equal => "==",
        .not_equal => "!=",
        .strict_equal => "===",
        .strict_not_equal => "!==",
        .less_than => ">",
        .less_than_or_equal => ">=",
        .greater_than => "<",
        .greater_than_or_equal => "<=",
        else => unreachable,
    };
}

fn sourceForRange(tree: *const ast.Tree, start: u32, end: u32) []const u8 {
    return tree.source[@intCast(start)..@intCast(end)];
}

fn hasExpectedYodaStyle(style: Style, left_literal: bool, right_literal: bool) bool {
    if (left_literal == right_literal) return true;

    return switch (style) {
        .never => !left_literal,
        .always => left_literal,
    };
}

fn message(style: Style) []const u8 {
    return switch (style) {
        .never => "Expected literal to be on the right side of comparison.",
        .always => "Expected literal to be on the left side of comparison.",
    };
}

fn isComparisonOperator(operator: ast.BinaryOperator) bool {
    return switch (operator) {
        .equal,
        .not_equal,
        .strict_equal,
        .strict_not_equal,
        .less_than,
        .less_than_or_equal,
        .greater_than,
        .greater_than_or_equal,
        => true,
        else => false,
    };
}

fn isEqualityOperator(operator: ast.BinaryOperator) bool {
    return switch (operator) {
        .equal,
        .not_equal,
        .strict_equal,
        .strict_not_equal,
        => true,
        else => false,
    };
}

fn isRelationalOperator(operator: ast.BinaryOperator) bool {
    return switch (operator) {
        .less_than,
        .less_than_or_equal,
        .greater_than,
        .greater_than_or_equal,
        => true,
        else => false,
    };
}

fn isRangeComparison(tree: *const ast.Tree, expression: ast.BinaryExpression, index: ast.NodeIndex, parent_index: ast.NodeIndex) bool {
    if (!isRelationalOperator(expression.operator)) return false;

    const logical = switch (tree.data(parent_index)) {
        .logical_expression => |logical| logical,
        else => return false,
    };
    if (logical.operator != .@"and" and logical.operator != .@"or") return false;

    const sibling_index = if (logical.left == index) logical.right else if (logical.right == index) logical.left else return false;
    const sibling = switch (tree.data(unwrapTransparent(tree, sibling_index))) {
        .binary_expression => |binary| binary,
        else => return false,
    };
    if (!isRelationalOperator(sibling.operator)) return false;

    const current_subject = comparisonSubject(tree, expression) orelse return false;
    const sibling_subject = comparisonSubject(tree, sibling) orelse return false;
    return sameNodeSource(tree, current_subject, sibling_subject);
}

fn comparisonSubject(tree: *const ast.Tree, expression: ast.BinaryExpression) ?ast.NodeIndex {
    const left_literal = isLiteralLike(tree, expression.left);
    const right_literal = isLiteralLike(tree, expression.right);
    if (left_literal == right_literal) return null;
    return if (left_literal) unwrapTransparent(tree, expression.right) else unwrapTransparent(tree, expression.left);
}

fn sameNodeSource(tree: *const ast.Tree, left: ast.NodeIndex, right: ast.NodeIndex) bool {
    const left_span = tree.span(left);
    const right_span = tree.span(right);
    return std.mem.eql(
        u8,
        tree.source[left_span.start..left_span.end],
        tree.source[right_span.start..right_span.end],
    );
}

fn isLiteralLike(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .string_literal,
        .numeric_literal,
        .boolean_literal,
        .null_literal,
        .bigint_literal,
        .regexp_literal,
        => true,
        .template_literal => |literal| literal.expressions.len == 0,
        .unary_expression => |expression| isNegativeNumericLiteral(tree, expression),
        else => false,
    };
}

fn isNegativeNumericLiteral(tree: *const ast.Tree, expression: ast.UnaryExpression) bool {
    if (expression.operator != .negate) return false;

    return switch (tree.data(unwrapTransparent(tree, expression.argument))) {
        .numeric_literal => true,
        else => false,
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
