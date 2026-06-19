const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-constant-binary-expression";

pub fn checkLogicalExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.LogicalExpression,
) Allocator.Error!void {
    const left = unwrapTransparent(tree, expression.left);

    switch (expression.operator) {
        .@"and", .@"or" => if (staticTruthiness(tree, left) != null) {
            try reportShortCircuit(allocator, diagnostics, tree, left, "truthiness", expression.operator.toString());
        },
        .nullish_coalescing => if (staticNullishness(tree, left) != null) {
            try reportShortCircuit(allocator, diagnostics, tree, left, "nullishness", expression.operator.toString());
        },
    }
}

pub fn checkBinaryExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
) Allocator.Error!void {
    const left = unwrapTransparent(tree, expression.left);
    const right = unwrapTransparent(tree, expression.right);

    if (constantComparisonOperand(tree, left, right, expression.operator)) |operand| {
        try reportConstantOperand(allocator, diagnostics, tree, operand, expression.operator.toString(), "left");
        return;
    }
    if (constantComparisonOperand(tree, right, left, expression.operator)) |operand| {
        try reportConstantOperand(allocator, diagnostics, tree, operand, expression.operator.toString(), "right");
        return;
    }

    switch (expression.operator) {
        .strict_equal, .strict_not_equal => {
            if (isAlwaysNew(tree, left)) {
                try reportAlwaysNew(allocator, diagnostics, tree, left, false);
            } else if (isAlwaysNew(tree, right)) {
                try reportAlwaysNew(allocator, diagnostics, tree, right, false);
            }
        },
        .equal, .not_equal => if (isAlwaysNew(tree, left) and isAlwaysNew(tree, right)) {
            try reportAlwaysNew(allocator, diagnostics, tree, left, true);
        },
        else => {},
    }
}

fn constantComparisonOperand(
    tree: *const ast.Tree,
    constant_side: ast.NodeIndex,
    other_side: ast.NodeIndex,
    operator: ast.BinaryOperator,
) ?ast.NodeIndex {
    switch (operator) {
        .equal, .not_equal => {
            if (isNullOrVoid(tree, constant_side) and staticNullishness(tree, other_side) != null) return other_side;
            if (isBooleanLiteral(tree, constant_side) and hasConstantLooseBooleanComparison(tree, other_side)) return other_side;
        },
        .strict_equal, .strict_not_equal => {
            if (isNullOrVoid(tree, constant_side) and staticNullishness(tree, other_side) != null) return other_side;
            if (isBooleanLiteral(tree, constant_side) and hasConstantStrictBooleanComparison(tree, other_side)) return other_side;
        },
        else => {},
    }
    return null;
}

fn reportShortCircuit(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    property: []const u8,
    operator: []const u8,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Unexpected constant {s} on the left-hand side of a `{s}` expression.",
        .{ property, operator },
    );
}

fn reportConstantOperand(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    operator: []const u8,
    other_side: []const u8,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Unexpected constant binary expression. Compares constantly with the {s}-hand side of the `{s}`.",
        .{ other_side, operator },
    );
}

fn reportAlwaysNew(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    both: bool,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        if (both)
            "Unexpected comparison of two newly constructed objects. These two values can never be equal."
        else
            "Unexpected comparison to newly constructed object. These two values can never be equal.",
        tree.span(index),
    );
}

fn staticNullishness(tree: *const ast.Tree, index: ast.NodeIndex) ?bool {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .null_literal => true,
        .boolean_literal,
        .numeric_literal,
        .bigint_literal,
        .string_literal,
        .regexp_literal,
        .array_expression,
        .object_expression,
        .arrow_function_expression,
        .template_literal,
        .update_expression,
        => false,
        .function => |function| if (function.type == .function_expression or function.type == .ts_empty_body_function_expression) false else null,
        .class => |class| if (class.type == .class_expression) false else null,
        .unary_expression => |unary| switch (unary.operator) {
            .void => true,
            .logical_not,
            .positive,
            .negate,
            .bitwise_not,
            .typeof,
            .delete,
            => false,
        },
        .binary_expression => |binary| if (isNumericOrStringBinaryOperator(binary.operator)) false else null,
        .logical_expression => |logical| if (logical.operator == .nullish_coalescing)
            staticNullishness(tree, unwrapTransparent(tree, logical.right))
        else
            null,
        .assignment_expression => |assignment| if (assignment.operator == .assign)
            staticNullishness(tree, unwrapTransparent(tree, assignment.right))
        else
            false,
        .sequence_expression => |sequence| lastExpression(tree, sequence.expressions, staticNullishness),
        else => null,
    };
}

fn staticTruthiness(tree: *const ast.Tree, index: ast.NodeIndex) ?bool {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .boolean_literal => |literal| literal.value,
        .null_literal => false,
        .numeric_literal => |literal| {
            const value = literal.value(tree);
            return value != 0 and value == value;
        },
        .bigint_literal => |literal| bigintTruthy(tree.string(literal.raw)),
        .string_literal => |literal| tree.string(literal.value).len != 0,
        .regexp_literal,
        .array_expression,
        .object_expression,
        .arrow_function_expression,
        => true,
        .template_literal => |literal| templateLiteralTruthy(tree, literal),
        .function => |function| if (function.type == .function_expression or function.type == .ts_empty_body_function_expression) true else null,
        .class => |class| if (class.type == .class_expression) true else null,
        .unary_expression => |unary| staticUnaryTruthiness(tree, unary),
        .assignment_expression => |assignment| if (assignment.operator == .assign) staticTruthiness(tree, unwrapTransparent(tree, assignment.right)) else null,
        .sequence_expression => |sequence| lastExpression(tree, sequence.expressions, staticTruthiness),
        else => null,
    };
}

fn hasConstantStrictBooleanComparison(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .boolean_literal,
        .null_literal,
        .numeric_literal,
        .bigint_literal,
        .string_literal,
        .regexp_literal,
        .array_expression,
        .object_expression,
        .arrow_function_expression,
        .template_literal,
        .update_expression,
        => true,
        .function => |function| function.type == .function_expression or function.type == .ts_empty_body_function_expression,
        .class => |class| class.type == .class_expression,
        .binary_expression => |binary| isNumericOrStringBinaryOperator(binary.operator),
        .unary_expression => |unary| unary.operator != .delete,
        .assignment_expression => |assignment| if (assignment.operator == .assign) hasConstantStrictBooleanComparison(tree, unwrapTransparent(tree, assignment.right)) else !isLogicalAssignmentOperator(assignment.operator),
        .sequence_expression => |sequence| lastBool(tree, sequence.expressions, hasConstantStrictBooleanComparison),
        else => false,
    };
}

fn hasConstantLooseBooleanComparison(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .boolean_literal,
        .null_literal,
        .numeric_literal,
        .bigint_literal,
        .string_literal,
        => true,
        .object_expression,
        .class,
        .arrow_function_expression,
        .function,
        => true,
        .array_expression => |array| {
            const elements = tree.extra(array.elements);
            var non_spread_count: usize = 0;
            for (elements) |element| {
                if (element == .null) continue;
                if (tree.data(element) == .spread_element) continue;
                non_spread_count += 1;
            }
            return elements.len == 0 or non_spread_count > 1;
        },
        .template_literal => |literal| literal.expressions.len == 0,
        .unary_expression => |unary| switch (unary.operator) {
            .void, .typeof => true,
            .logical_not => staticTruthiness(tree, unwrapTransparent(tree, unary.argument)) != null,
            else => false,
        },
        .assignment_expression => |assignment| if (assignment.operator == .assign) hasConstantLooseBooleanComparison(tree, unwrapTransparent(tree, assignment.right)) else false,
        .sequence_expression => |sequence| lastBool(tree, sequence.expressions, hasConstantLooseBooleanComparison),
        else => false,
    };
}

fn isAlwaysNew(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .object_expression,
        .array_expression,
        .arrow_function_expression,
        .regexp_literal,
        => true,
        .function => |function| function.type == .function_expression or function.type == .ts_empty_body_function_expression,
        .class => |class| class.type == .class_expression,
        .assignment_expression => |assignment| assignment.operator == .assign and isAlwaysNew(tree, unwrapTransparent(tree, assignment.right)),
        .conditional_expression => |conditional| isAlwaysNew(tree, unwrapTransparent(tree, conditional.consequent)) and
            isAlwaysNew(tree, unwrapTransparent(tree, conditional.alternate)),
        .sequence_expression => |sequence| lastBool(tree, sequence.expressions, isAlwaysNew),
        else => false,
    };
}

fn isNullOrVoid(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .null_literal => true,
        .unary_expression => |unary| unary.operator == .void,
        else => false,
    };
}

fn isBooleanLiteral(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .boolean_literal => true,
        else => false,
    };
}

fn isNumericOrStringBinaryOperator(operator: ast.BinaryOperator) bool {
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

fn isLogicalAssignmentOperator(operator: ast.AssignmentOperator) bool {
    return switch (operator) {
        .logical_or_assign,
        .logical_and_assign,
        .nullish_assign,
        => true,
        else => false,
    };
}

fn staticUnaryTruthiness(tree: *const ast.Tree, unary: ast.UnaryExpression) ?bool {
    const argument = unwrapTransparent(tree, unary.argument);
    return switch (unary.operator) {
        .logical_not => if (staticTruthiness(tree, argument)) |truthy| !truthy else null,
        .positive,
        .negate,
        => switch (tree.data(argument)) {
            .numeric_literal => staticTruthiness(tree, argument),
            else => null,
        },
        .void => false,
        .bitwise_not,
        .typeof,
        .delete,
        => null,
    };
}

fn templateLiteralTruthy(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?bool {
    if (literal.expressions.len != 0) return null;

    const quasis = tree.extra(literal.quasis);
    if (quasis.len != 1) return null;

    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked).len != 0,
        else => null,
    };
}

fn bigintTruthy(raw: []const u8) bool {
    for (raw) |char| {
        if (char == '_' or char == 'n') continue;
        if (char != '0') return true;
    }
    return false;
}

fn lastExpression(
    tree: *const ast.Tree,
    range: ast.IndexRange,
    comptime callback: fn (*const ast.Tree, ast.NodeIndex) ?bool,
) ?bool {
    const items = tree.extra(range);
    if (items.len == 0) return null;
    return callback(tree, unwrapTransparent(tree, items[items.len - 1]));
}

fn lastBool(
    tree: *const ast.Tree,
    range: ast.IndexRange,
    comptime callback: fn (*const ast.Tree, ast.NodeIndex) bool,
) bool {
    const items = tree.extra(range);
    if (items.len == 0) return false;
    return callback(tree, unwrapTransparent(tree, items[items.len - 1]));
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
