const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "use-isnan";

pub const Options = struct {
    enforce_for_index_of: bool = false,
    enforce_for_switch_case: bool = true,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkBinaryExpressionWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkBinaryExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.BinaryExpression,
    index: ast.NodeIndex,
    _: Options,
) Allocator.Error!void {
    if (!isComparisonOperator(expression.operator)) return;
    if (!isNaNReference(tree, expression.left) and !isNaNReference(tree, expression.right)) return;

    try report(allocator, diagnostics, tree, index, "Use Number.isNaN or isNaN to compare with NaN.");
}

pub fn checkSwitchStatementWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.SwitchStatement,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (!options.enforce_for_switch_case) return;
    if (!isNaNReference(tree, statement.discriminant)) return;

    try report(allocator, diagnostics, tree, index, "'switch(NaN)' can never match a case clause.");
}

pub fn checkSwitchCaseWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    switch_case: ast.SwitchCase,
    options: Options,
) Allocator.Error!void {
    if (!options.enforce_for_switch_case) return;
    if (!isNaNReference(tree, switch_case.@"test")) return;

    try report(allocator, diagnostics, tree, switch_case.@"test", "'case NaN' can never match.");
}

pub fn checkCallExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    options: Options,
) Allocator.Error!void {
    if (!options.enforce_for_index_of) return;
    if (!isIndexOfCall(tree, call)) return;

    for (tree.extra(call.arguments)) |argument| {
        if (!isNaNReference(tree, argument)) continue;
        try report(allocator, diagnostics, tree, argument, "Use Number.isNaN or isNaN to compare with NaN.");
    }
}

fn report(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    message: []const u8,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        message,
        tree.span(index),
    );
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

fn isNaNReference(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), "NaN"),
        .member_expression => |member| isNumberNaNMember(tree, member),
        .chain_expression => |chain| isNaNReference(tree, chain.expression),
        .parenthesized_expression => |parenthesized| isNaNReference(tree, parenthesized.expression),
        .sequence_expression => |sequence| {
            const expressions = tree.extra(sequence.expressions);
            return expressions.len > 0 and isNaNReference(tree, expressions[expressions.len - 1]);
        },
        else => false,
    };
}

fn isNumberNaNMember(tree: *const ast.Tree, member: ast.MemberExpression) bool {
    const object_name = identifierReferenceName(tree, member.object) orelse return false;
    if (!std.mem.eql(u8, object_name, "Number")) return false;

    const property_name = propertyName(tree, member.property, member.computed) orelse return false;
    return std.mem.eql(u8, property_name, "NaN");
}

fn isIndexOfCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const callee = switch (tree.data(call.callee)) {
        .member_expression => |member| member,
        else => return false,
    };

    const property_name = propertyName(tree, callee.property, callee.computed) orelse return false;
    return std.mem.eql(u8, property_name, "indexOf") or
        std.mem.eql(u8, property_name, "lastIndexOf");
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .chain_expression => |chain| identifierReferenceName(tree, chain.expression),
        .parenthesized_expression => |parenthesized| identifierReferenceName(tree, parenthesized.expression),
        else => null,
    };
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (index == .null) return null;
    if (computed) {
        return switch (tree.data(index)) {
            .string_literal => |literal| tree.string(literal.value),
            .parenthesized_expression => |parenthesized| propertyName(tree, parenthesized.expression, true),
            else => null,
        };
    }
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}
