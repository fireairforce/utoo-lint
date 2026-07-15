const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "logical-assignment-operators";

pub const Style = enum {
    always,
    never,
};

pub const Options = struct {
    style: Style = .always,
};

const Reference = union(enum) {
    this,
    identifier: []const u8,
    member: struct {
        object: *const Reference,
        property: []const u8,
    },
};

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkAssignmentExpressionWithContextAndOptions(allocator, diagnostics, tree, expression, index, null, .{});
}

pub fn checkAssignmentExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    try checkAssignmentExpressionWithContextAndOptions(allocator, diagnostics, tree, expression, index, null, options);
}

pub fn checkAssignmentExpressionWithContextAndOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
    ctx: ?*traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (options.style == .never) {
        try checkLogicalAssignmentOperator(allocator, diagnostics, tree, expression, index, ctx);
        return;
    }

    if (expression.operator != .assign) return;

    const logical = switch (tree.data(unwrapTransparent(tree, expression.right))) {
        .logical_expression => |logical| logical,
        else => return,
    };

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const left = (try referenceFromExpression(arena_allocator, tree, expression.left)) orelse return;
    const right_left = (try referenceFromExpression(arena_allocator, tree, logical.left)) orelse return;
    if (!referencesEqual(left, right_left)) return;

    const replacement = if (isSafeDirectIdentifier(tree, expression.left, ctx) and !hasCommentInSpan(tree, tree.span(index)))
        try std.fmt.allocPrint(allocator, "{s} {s}= {s}", .{
            tree.source[tree.span(expression.left).start..tree.span(expression.left).end],
            logical.operator.toString(),
            tree.source[tree.span(logical.right).start..tree.span(logical.right).end],
        })
    else
        null;
    defer if (replacement) |value| allocator.free(value);

    try addDiagnostic(allocator, diagnostics, tree, index, logical.operator, if (replacement) |value| .{
        .span = tree.span(index),
        .replacement = value,
    } else null);
}

fn checkLogicalAssignmentOperator(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
    ctx: ?*traverser.basic.Ctx,
) Allocator.Error!void {
    const operator = logicalOperatorFromAssignment(expression.operator) orelse return;
    const parenthesize_right = rightNeedsParentheses(tree, expression.right, operator);
    const replacement = if (isSafeDirectIdentifier(tree, expression.left, ctx) and !hasCommentInSpan(tree, tree.span(index)))
        try std.fmt.allocPrint(allocator, "{s} = {s} {s} {s}{s}{s}", .{
            tree.source[tree.span(expression.left).start..tree.span(expression.left).end],
            tree.source[tree.span(expression.left).start..tree.span(expression.left).end],
            operator.toString(),
            if (parenthesize_right) "(" else "",
            tree.source[tree.span(expression.right).start..tree.span(expression.right).end],
            if (parenthesize_right) ")" else "",
        })
    else
        null;
    defer if (replacement) |value| allocator.free(value);

    if (replacement) |value| {
        const message = try std.fmt.allocPrint(allocator, "Unexpected logical assignment operator `{s}=`.", .{operator.toString()});
        defer allocator.free(message);
        try core.addDiagnosticWithFix(
            allocator,
            diagnostics,
            .warning,
            id,
            message,
            tree.span(index),
            .{ .span = tree.span(index), .replacement = value },
        );
        return;
    }

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Unexpected logical assignment operator `{s}=`.",
        .{operator.toString()},
    );
}

pub fn checkLogicalExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.LogicalExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkLogicalExpressionWithContext(allocator, diagnostics, tree, expression, index, null);
}

pub fn checkLogicalExpressionWithContext(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.LogicalExpression,
    index: ast.NodeIndex,
    ctx: ?*traverser.basic.Ctx,
) Allocator.Error!void {
    const assignment = switch (tree.data(unwrapTransparent(tree, expression.right))) {
        .assignment_expression => |assignment| assignment,
        else => return,
    };
    if (assignment.operator != .assign) return;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const left = (try referenceFromExpression(arena_allocator, tree, expression.left)) orelse return;
    const assignment_left = (try referenceFromExpression(arena_allocator, tree, assignment.left)) orelse return;
    if (!referencesEqual(left, assignment_left)) return;

    const parenthesize = logicalReplacementNeedsParentheses(tree, ctx);
    const replacement = if (isSafeShortCircuitReference(tree, expression.left, ctx) and !hasCommentInSpan(tree, tree.span(index)))
        try std.fmt.allocPrint(allocator, "{s}{s} {s}= {s}{s}", .{
            if (parenthesize) "(" else "",
            tree.source[tree.span(expression.left).start..tree.span(expression.left).end],
            expression.operator.toString(),
            tree.source[tree.span(assignment.right).start..tree.span(assignment.right).end],
            if (parenthesize) ")" else "",
        })
    else
        null;
    defer if (replacement) |value| allocator.free(value);

    try addDiagnostic(allocator, diagnostics, tree, index, expression.operator, if (replacement) |value| .{
        .span = tree.span(index),
        .replacement = value,
    } else null);
}

pub fn checkIfStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.IfStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkIfStatementWithContext(allocator, diagnostics, tree, statement, index, null);
}

pub fn checkIfStatementWithContext(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.IfStatement,
    index: ast.NodeIndex,
    ctx: ?*traverser.basic.Ctx,
) Allocator.Error!void {
    if (statement.alternate != .null) return;

    const assignment = assignmentFromStatement(tree, statement.consequent) orelse return;
    if (assignment.operator != .assign) return;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const test_reference = (try conditionReference(arena_allocator, tree, statement.@"test")) orelse return;
    const assignment_left = (try referenceFromExpression(arena_allocator, tree, assignment.left)) orelse return;
    if (!referencesEqual(test_reference.reference, assignment_left)) return;

    const replacement = if (isSafeShortCircuitReference(tree, assignment.left, ctx) and
        hasSafeStatementStart(tree, assignment.left) and
        !hasCommentInSpan(tree, tree.span(index)))
        try std.fmt.allocPrint(allocator, "{s} {s}= {s};", .{
            tree.source[tree.span(assignment.left).start..tree.span(assignment.left).end],
            test_reference.operator.toString(),
            tree.source[tree.span(assignment.right).start..tree.span(assignment.right).end],
        })
    else
        null;
    defer if (replacement) |value| allocator.free(value);

    try addDiagnostic(allocator, diagnostics, tree, index, test_reference.operator, if (replacement) |value| .{
        .span = tree.span(index),
        .replacement = value,
    } else null);
}

const ConditionReference = struct {
    reference: *const Reference,
    operator: ast.LogicalOperator,
};

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    operator: ast.LogicalOperator,
    fix: ?core.Fix,
) Allocator.Error!void {
    if (fix) |value| {
        const message = try std.fmt.allocPrint(allocator, "Assignment can be replaced with `{s}=`.", .{operator.toString()});
        defer allocator.free(message);
        try core.addDiagnosticWithFix(
            allocator,
            diagnostics,
            .warning,
            id,
            message,
            tree.span(index),
            value,
        );
        return;
    }

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Assignment can be replaced with `{s}=`.",
        .{operator.toString()},
    );
}

fn isSafeDirectIdentifier(tree: *const ast.Tree, index: ast.NodeIndex, ctx: ?*traverser.basic.Ctx) bool {
    if (ctx == null or isInsideWithStatement(tree, ctx.?)) return false;
    return tree.data(unwrapTransparent(tree, index)) == .identifier_reference;
}

fn isSafeShortCircuitReference(tree: *const ast.Tree, index: ast.NodeIndex, ctx: ?*traverser.basic.Ctx) bool {
    if (isSafeDirectIdentifier(tree, index, ctx)) return true;
    if (ctx == null or isInsideWithStatement(tree, ctx.?)) return false;

    const member = switch (tree.data(unwrapTransparent(tree, index))) {
        .member_expression => |member| member,
        else => return false,
    };
    if (propertyName(tree, member) == null) return false;
    return switch (tree.data(unwrapTransparent(tree, member.object))) {
        .identifier_reference, .this_expression => true,
        else => false,
    };
}

fn isInsideWithStatement(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        if (tree.data(ancestor) == .with_statement) return true;
    }
    return false;
}

fn logicalReplacementNeedsParentheses(tree: *const ast.Tree, ctx: ?*traverser.basic.Ctx) bool {
    const context = ctx orelse return true;
    const parent = context.path.ancestor(1) orelse return true;
    return switch (tree.data(parent)) {
        .expression_statement, .parenthesized_expression => false,
        else => true,
    };
}

fn hasSafeStatementStart(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const span = tree.span(index);
    if (span.start >= span.end) return false;
    const first = tree.source[span.start];
    return first == '_' or first == '$' or std.ascii.isAlphabetic(first) or first >= 0x80;
}

fn hasCommentInSpan(tree: *const ast.Tree, span: ast.Span) bool {
    for (tree.comments) |comment| {
        if (comment.span.start < span.end and comment.span.end > span.start) return true;
    }
    return false;
}

fn logicalOperatorFromAssignment(operator: ast.AssignmentOperator) ?ast.LogicalOperator {
    return switch (operator) {
        .logical_or_assign => .@"or",
        .logical_and_assign => .@"and",
        .nullish_assign => .nullish_coalescing,
        else => null,
    };
}

fn rightNeedsParentheses(tree: *const ast.Tree, index: ast.NodeIndex, operator: ast.LogicalOperator) bool {
    if (tree.data(index) == .parenthesized_expression) return false;
    const precedence = expressionPrecedence(tree, index);
    const operator_precedence: u8 = switch (operator) {
        .@"or", .nullish_coalescing => 3,
        .@"and" => 4,
    };
    if (precedence <= operator_precedence) return true;

    return operator == .nullish_coalescing and switch (tree.data(unwrapTransparent(tree, index))) {
        .logical_expression => true,
        else => false,
    };
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

fn conditionReference(
    allocator: Allocator,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!?ConditionReference {
    const unwrapped = unwrapTransparent(tree, index);
    switch (tree.data(unwrapped)) {
        .unary_expression => |expression| {
            if (expression.operator != .logical_not) return null;
            const reference = (try referenceFromExpression(allocator, tree, expression.argument)) orelse return null;
            return .{
                .reference = reference,
                .operator = .@"or",
            };
        },
        .binary_expression => |expression| {
            if (expression.operator != .equal) return null;
            if (isNullLiteral(tree, expression.left)) {
                const reference = (try referenceFromExpression(allocator, tree, expression.right)) orelse return null;
                return .{
                    .reference = reference,
                    .operator = .nullish_coalescing,
                };
            }
            if (isNullLiteral(tree, expression.right)) {
                const reference = (try referenceFromExpression(allocator, tree, expression.left)) orelse return null;
                return .{
                    .reference = reference,
                    .operator = .nullish_coalescing,
                };
            }
            return null;
        },
        else => {
            const reference = (try referenceFromExpression(allocator, tree, unwrapped)) orelse return null;
            return .{
                .reference = reference,
                .operator = .@"and",
            };
        },
    }
}

fn assignmentFromStatement(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.AssignmentExpression {
    const unwrapped = unwrapTransparent(tree, index);
    switch (tree.data(unwrapped)) {
        .expression_statement => |statement| return assignmentFromExpression(tree, statement.expression),
        .block_statement => |block| {
            const statements = tree.extra(block.body);
            if (statements.len != 1) return null;
            return assignmentFromStatement(tree, statements[0]);
        },
        else => return null,
    }
}

fn assignmentFromExpression(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.AssignmentExpression {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .assignment_expression => |assignment| assignment,
        else => null,
    };
}

fn isNullLiteral(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .null_literal => true,
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
            .template_literal => |literal| templateStringValue(tree, literal),
            else => null,
        }
    else switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .private_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn templateStringValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;

    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return "";

    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
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
