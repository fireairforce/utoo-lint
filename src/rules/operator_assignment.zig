const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "operator-assignment";

pub const Options = struct {
    style: core.OperatorAssignmentStyle = .always,
};

const Reference = union(enum) {
    this,
    identifier: []const u8,
    member: struct {
        object: *const Reference,
        property: []const u8,
    },
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    return checkWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (options.style == .never) {
        if (!isCompoundAssignmentOperator(expression.operator)) return;
        if (try neverFix(allocator, tree, expression, index)) |fix| {
            defer allocator.free(fix.replacement);
            return core.addDiagnosticWithFix(
                allocator,
                diagnostics,
                .warning,
                id,
                "Assignment operator shorthand is not allowed.",
                tree.span(index),
                fix,
            );
        }
        return core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Assignment operator shorthand is not allowed.",
            tree.span(index),
        );
    }

    if (expression.operator != .assign) return;

    const binary_index = unwrapTransparent(tree, expression.right);
    const binary = switch (tree.data(binary_index)) {
        .binary_expression => |binary| binary,
        else => return,
    };
    if (!hasAssignmentOperator(binary.operator)) return;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const left = (try referenceFromExpression(arena_allocator, tree, expression.left)) orelse return;
    const right_left = (try referenceFromExpression(arena_allocator, tree, binary.left)) orelse return;
    const repeats_left = referencesEqual(left, right_left);
    if (!repeats_left) {
        if (!hasCommutativeAssignmentOperator(binary.operator)) return;
        const right_right = (try referenceFromExpression(arena_allocator, tree, binary.right)) orelse return;
        if (!referencesEqual(left, right_right)) return;
    }

    if (repeats_left) {
        if (try alwaysFix(allocator, tree, expression, index, binary, binary_index)) |fix| {
            defer allocator.free(fix.replacement);
            return core.addDiagnosticWithFix(
                allocator,
                diagnostics,
                .warning,
                id,
                "Assignment can be replaced with operator assignment.",
                tree.span(index),
                fix,
            );
        }
    }

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Assignment can be replaced with operator assignment.",
        tree.span(index),
    );
}

fn neverFix(
    allocator: Allocator,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
) Allocator.Error!?core.Fix {
    if (!canBeFixed(tree, expression.left)) return null;
    const operator_text = expression.operator.toString();
    const operator_span = findOperatorSpan(
        tree,
        tree.span(expression.left).end,
        tree.span(expression.right).start,
        operator_text,
    ) orelse return null;
    const assignment_span = tree.span(index);
    if (hasCommentBetween(tree, assignment_span.start, operator_span.start)) return null;

    const left_text = tree.source[assignment_span.start..operator_span.start];
    const operator = baseOperator(expression.operator);
    if (rightNeedsParentheses(tree, expression.right, expression.operator)) {
        const right_span = tree.span(expression.right);
        const gap = tree.source[operator_span.end..right_span.start];
        const right_text = tree.source[right_span.start..right_span.end];
        return .{
            .span = assignment_span,
            .replacement = try std.fmt.allocPrint(
                allocator,
                "{s}= {s}{s}{s}({s})",
                .{ left_text, left_text, operator, gap, right_text },
            ),
        };
    }

    const right_text = tree.source[operator_span.end..assignment_span.end];
    const separator = if (right_text.len > 0 and tokensNeedSeparation(operator[operator.len - 1], right_text[0])) " " else "";
    return .{
        .span = assignment_span,
        .replacement = try std.fmt.allocPrint(
            allocator,
            "{s}= {s}{s}{s}{s}",
            .{ left_text, left_text, operator, separator, right_text },
        ),
    };
}

fn tokensNeedSeparation(left: u8, right: u8) bool {
    return (left == '+' and right == '+') or
        (left == '-' and right == '-') or
        (left == '/' and (right == '/' or right == '*'));
}

fn alwaysFix(
    allocator: Allocator,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
    binary: ast.BinaryExpression,
    binary_index: ast.NodeIndex,
) Allocator.Error!?core.Fix {
    if (!canBeFixed(tree, expression.left) or !canBeFixed(tree, binary.left)) return null;

    const assignment_span = tree.span(index);
    const equals_span = findOperatorSpan(
        tree,
        tree.span(expression.left).end,
        tree.span(expression.right).start,
        "=",
    ) orelse return null;
    const operator_text = binary.operator.toString();
    const operator_span = findOperatorSpan(
        tree,
        tree.span(binary.left).end,
        tree.span(binary.right).start,
        operator_text,
    ) orelse return null;
    if (hasCommentBetween(tree, equals_span.end, operator_span.start)) return null;

    const left_text = tree.source[assignment_span.start..equals_span.start];
    const right_text = try allocAlwaysRightText(
        allocator,
        tree,
        expression.right,
        binary_index,
        operator_span.end,
    );
    defer allocator.free(right_text);
    return .{
        .span = assignment_span,
        .replacement = try std.fmt.allocPrint(allocator, "{s}{s}={s}", .{ left_text, operator_text, right_text }),
    };
}

fn allocAlwaysRightText(
    allocator: Allocator,
    tree: *const ast.Tree,
    wrapped_index: ast.NodeIndex,
    binary_index: ast.NodeIndex,
    start: u32,
) Allocator.Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    const binary_end = tree.span(binary_index).end;
    try output.appendSlice(allocator, tree.source[start..binary_end]);

    const wrapped_end = tree.span(wrapped_index).end;
    var cursor: usize = binary_end;
    while (cursor < wrapped_end) : (cursor += 1) {
        if (isTransparentClosingParenthesis(tree, wrapped_index, binary_index, cursor)) continue;
        try output.append(allocator, tree.source[cursor]);
    }
    return output.toOwnedSlice(allocator);
}

fn isTransparentClosingParenthesis(
    tree: *const ast.Tree,
    wrapped_index: ast.NodeIndex,
    target_index: ast.NodeIndex,
    offset: usize,
) bool {
    var current = wrapped_index;
    while (current != target_index) {
        switch (tree.data(current)) {
            .parenthesized_expression => |parenthesized| {
                if (tree.span(current).end - 1 == offset) return true;
                current = parenthesized.expression;
            },
            .chain_expression => |chain| current = chain.expression,
            else => return false,
        }
    }
    return false;
}

fn isCompoundAssignmentOperator(operator: ast.AssignmentOperator) bool {
    return switch (operator) {
        .add_assign,
        .subtract_assign,
        .multiply_assign,
        .divide_assign,
        .modulo_assign,
        .exponent_assign,
        .left_shift_assign,
        .right_shift_assign,
        .unsigned_right_shift_assign,
        .bitwise_or_assign,
        .bitwise_xor_assign,
        .bitwise_and_assign,
        => true,
        else => false,
    };
}

fn baseOperator(operator: ast.AssignmentOperator) []const u8 {
    return switch (operator) {
        .add_assign => "+",
        .subtract_assign => "-",
        .multiply_assign => "*",
        .divide_assign => "/",
        .modulo_assign => "%",
        .exponent_assign => "**",
        .left_shift_assign => "<<",
        .right_shift_assign => ">>",
        .unsigned_right_shift_assign => ">>>",
        .bitwise_or_assign => "|",
        .bitwise_xor_assign => "^",
        .bitwise_and_assign => "&",
        else => unreachable,
    };
}

fn rightNeedsParentheses(
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    operator: ast.AssignmentOperator,
) bool {
    if (tree.data(index) == .parenthesized_expression) return false;
    return expressionPrecedence(tree, index) <= assignmentOperatorPrecedence(operator);
}

fn expressionPrecedence(tree: *const ast.Tree, index: ast.NodeIndex) u8 {
    return switch (tree.data(index)) {
        .sequence_expression => 1,
        .assignment_expression,
        .arrow_function_expression,
        .yield_expression,
        .conditional_expression,
        => 2,
        .logical_expression => |logical| switch (logical.operator) {
            .@"or", .nullish_coalescing => 3,
            .@"and" => 4,
        },
        .binary_expression => |binary| binaryOperatorPrecedence(binary.operator),
        .ts_as_expression, .ts_satisfies_expression => 9,
        .unary_expression, .await_expression, .ts_type_assertion => 14,
        .update_expression => 15,
        .new_expression,
        .call_expression,
        .member_expression,
        .chain_expression,
        .tagged_template_expression,
        .import_expression,
        .ts_non_null_expression,
        .ts_instantiation_expression,
        => 17,
        else => 18,
    };
}

fn assignmentOperatorPrecedence(operator: ast.AssignmentOperator) u8 {
    return switch (operator) {
        .bitwise_or_assign => 5,
        .bitwise_xor_assign => 6,
        .bitwise_and_assign => 7,
        .left_shift_assign, .right_shift_assign, .unsigned_right_shift_assign => 10,
        .add_assign, .subtract_assign => 11,
        .multiply_assign, .divide_assign, .modulo_assign => 12,
        .exponent_assign => 13,
        else => unreachable,
    };
}

fn binaryOperatorPrecedence(operator: ast.BinaryOperator) u8 {
    return switch (operator) {
        .bitwise_or => 5,
        .bitwise_xor => 6,
        .bitwise_and => 7,
        .equal, .not_equal, .strict_equal, .strict_not_equal => 8,
        .less_than,
        .less_than_or_equal,
        .greater_than,
        .greater_than_or_equal,
        .in,
        .instanceof,
        => 9,
        .left_shift, .right_shift, .unsigned_right_shift => 10,
        .add, .subtract => 11,
        .multiply, .divide, .modulo => 12,
        .exponent => 13,
    };
}

fn hasAssignmentOperator(operator: ast.BinaryOperator) bool {
    return switch (operator) {
        .add,
        .subtract,
        .multiply,
        .divide,
        .modulo,
        .exponent,
        .bitwise_or,
        .bitwise_xor,
        .bitwise_and,
        .left_shift,
        .right_shift,
        .unsigned_right_shift,
        => true,
        else => false,
    };
}

fn hasCommutativeAssignmentOperator(operator: ast.BinaryOperator) bool {
    return switch (operator) {
        .multiply,
        .bitwise_or,
        .bitwise_xor,
        .bitwise_and,
        => true,
        else => false,
    };
}

fn referenceFromExpression(
    allocator: Allocator,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!?*const Reference {
    if (index == .null) return null;

    switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| return try newReference(allocator, .{ .identifier = tree.string(identifier.name) }),
        .this_expression => return newReference(allocator, .this),
        .member_expression => |member| {
            const object = (try referenceFromExpression(allocator, tree, member.object)) orelse return null;
            const property = propertyName(tree, member) orelse return null;
            return try newReference(allocator, .{ .member = .{
                .object = object,
                .property = property,
            } });
        },
        else => return null,
    }
}

fn newReference(allocator: Allocator, reference: Reference) Allocator.Error!*const Reference {
    const owned = try allocator.create(Reference);
    owned.* = reference;
    return owned;
}

fn referencesEqual(left: *const Reference, right: *const Reference) bool {
    switch (left.*) {
        .this => return right.* == .this,
        .identifier => |left_name| return switch (right.*) {
            .identifier => |right_name| std.mem.eql(u8, left_name, right_name),
            else => false,
        },
        .member => |left_member| return switch (right.*) {
            .member => |right_member| std.mem.eql(u8, left_member.property, right_member.property) and
                referencesEqual(left_member.object, right_member.object),
            else => false,
        },
    }
}

fn propertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;

    return if (member.computed)
        switch (tree.data(member.property)) {
            .identifier_reference => |identifier| tree.string(identifier.name),
            .string_literal => |literal| tree.string(literal.value),
            .numeric_literal => |literal| tree.string(literal.raw),
            else => null,
        }
    else switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .private_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn canBeFixed(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const unwrapped = unwrapParentheses(tree, index);
    return switch (tree.data(unwrapped)) {
        .identifier_reference => true,
        .member_expression => |member| blk: {
            const object = unwrapParentheses(tree, member.object);
            switch (tree.data(object)) {
                .identifier_reference, .this_expression => {},
                else => break :blk false,
            }
            if (!member.computed) break :blk true;
            break :blk switch (tree.data(member.property)) {
                .string_literal, .numeric_literal => true,
                else => false,
            };
        },
        else => false,
    };
}

fn findOperatorSpan(
    tree: *const ast.Tree,
    start: u32,
    end: u32,
    operator: []const u8,
) ?ast.Span {
    var cursor: usize = start;
    const limit: usize = end;
    while (cursor + operator.len <= limit) {
        if (commentContaining(tree, cursor)) |comment| {
            cursor = comment.span.end;
            continue;
        }
        if (std.mem.eql(u8, tree.source[cursor .. cursor + operator.len], operator)) {
            return .{ .start = @intCast(cursor), .end = @intCast(cursor + operator.len) };
        }
        cursor += 1;
    }
    return null;
}

fn commentContaining(tree: *const ast.Tree, offset: usize) ?ast.Comment {
    for (tree.comments) |comment| {
        if (comment.span.start > offset) return null;
        if (comment.span.start <= offset and offset < comment.span.end) return comment;
    }
    return null;
}

fn hasCommentBetween(tree: *const ast.Tree, start: u32, end: u32) bool {
    for (tree.comments) |comment| {
        if (comment.span.start >= end) return false;
        if (comment.span.end > start) return true;
    }
    return false;
}

fn unwrapParentheses(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;
    while (current != .null and tree.data(current) == .parenthesized_expression) {
        current = tree.data(current).parenthesized_expression.expression;
    }
    return current;
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
