const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-implicit-coercion";

pub const Options = struct {
    boolean: bool = true,
    number: bool = true,
    string: bool = true,
    allow_double_negation: bool = false,
    allow_bitwise_not: bool = false,
    allow_unary_plus: bool = false,
    allow_multiply: bool = false,
    allow_subtract: bool = false,
};

pub fn checkUnaryExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.UnaryExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkUnaryExpressionWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkUnaryExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.UnaryExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    switch (expression.operator) {
        .logical_not => {
            if (options.boolean and !options.allow_double_negation and isDoubleNegation(tree, expression)) {
                try addDiagnostic(allocator, diagnostics, tree, index, "Use `Boolean()` instead of double negation.");
            }
        },
        .bitwise_not => {
            if (options.boolean and !options.allow_bitwise_not and isIndexOfCall(tree, expression.argument)) {
                try addDiagnostic(allocator, diagnostics, tree, index, "Use an explicit comparison instead of bitwise negation.");
            }
        },
        .positive => {
            if (options.number and !options.allow_unary_plus and !isNumeric(tree, expression.argument)) {
                try addDiagnostic(allocator, diagnostics, tree, index, "Use `Number()` instead of unary plus.");
            }
        },
        .negate => {
            if (options.number and isNegatedExpression(tree, expression.argument)) {
                try addDiagnostic(allocator, diagnostics, tree, index, "Use `Number()` instead of double negation.");
            }
        },
        else => {},
    }
}

pub fn checkBinaryExpression(
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
    options: Options,
) Allocator.Error!void {
    switch (expression.operator) {
        .add => {
            if (options.string and isConcatWithEmptyString(tree, expression)) {
                try addDiagnostic(allocator, diagnostics, tree, index, "Use `String()` instead of string concatenation.");
            }
        },
        .subtract => {
            if (options.number and !options.allow_subtract and isZeroLiteral(tree, expression.right) and !isNumeric(tree, expression.left)) {
                try addDiagnostic(allocator, diagnostics, tree, index, "Use `Number()` instead of subtracting zero.");
            }
        },
        .multiply => {
            if (options.number and !options.allow_multiply and ((isOneLiteral(tree, expression.left) and !isNumeric(tree, expression.right)) or
                (isOneLiteral(tree, expression.right) and !isNumeric(tree, expression.left))))
            {
                try addDiagnostic(allocator, diagnostics, tree, index, "Use `Number()` instead of multiplying by one.");
            }
        },
        else => {},
    }
}

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkAssignmentExpressionWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkAssignmentExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (options.string and expression.operator == .add_assign and isEmptyStringLiteral(tree, expression.right)) {
        try addDiagnostic(allocator, diagnostics, tree, index, "Use `String()` instead of appending an empty string.");
    }
}

fn isDoubleNegation(tree: *const ast.Tree, expression: ast.UnaryExpression) bool {
    const inner = switch (tree.data(unwrapTransparent(tree, expression.argument))) {
        .unary_expression => |unary| unary,
        else => return false,
    };
    return inner.operator == .logical_not;
}

fn isNegatedExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const inner = switch (tree.data(unwrapTransparent(tree, index))) {
        .unary_expression => |unary| unary,
        else => return false,
    };
    return inner.operator == .negate and !isNumeric(tree, inner.argument);
}

fn isIndexOfCall(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const call = switch (tree.data(unwrapTransparent(tree, index))) {
        .call_expression => |call| call,
        else => return false,
    };

    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return false,
    };

    const name = propertyName(tree, member) orelse return false;
    return std.mem.eql(u8, name, "indexOf") or std.mem.eql(u8, name, "lastIndexOf");
}

fn propertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;

    return if (member.computed)
        switch (tree.data(member.property)) {
            .string_literal => |literal| tree.string(literal.value),
            .template_literal => |literal| templateStringValue(tree, literal),
            else => null,
        }
    else switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
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

fn isEmptyStringLiteral(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .string_literal => |literal| tree.string(literal.value).len == 0,
        .template_literal => |literal| literal.expressions.len == 0 and
            literal.quasis.len == 1 and isEmptyTemplateElement(tree, literal.quasis),
        else => false,
    };
}

fn isEmptyTemplateElement(tree: *const ast.Tree, range: ast.IndexRange) bool {
    const quasi_index = tree.extra(range)[0];
    return switch (tree.data(quasi_index)) {
        .template_element => |element| tree.string(element.cooked).len == 0,
        else => false,
    };
}

fn isConcatWithEmptyString(tree: *const ast.Tree, expression: ast.BinaryExpression) bool {
    return (isEmptyStringLiteral(tree, expression.left) and !isStringType(tree, expression.right)) or
        (isEmptyStringLiteral(tree, expression.right) and !isStringType(tree, expression.left));
}

fn isStringType(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return isStringLiteral(tree, index) or isNamedCall(tree, index, "String");
}

fn isStringLiteral(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .string_literal => true,
        .template_literal => true,
        else => false,
    };
}

fn isZeroLiteral(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return numericLiteralEquals(tree, index, "0");
}

fn isOneLiteral(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return numericLiteralEquals(tree, index, "1");
}

fn numericLiteralEquals(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .numeric_literal => |literal| std.mem.eql(u8, tree.string(literal.raw), expected),
        else => false,
    };
}

fn isNumeric(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .numeric_literal => true,
        .call_expression => |call| isNamedCallExpression(tree, call),
        else => false,
    };
}

fn isNamedCall(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    const call = switch (tree.data(unwrapTransparent(tree, index))) {
        .call_expression => |call| call,
        else => return false,
    };
    const callee_name = callCalleeName(tree, call) orelse return false;
    return std.mem.eql(u8, callee_name, name);
}

fn isNamedCallExpression(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const name = callCalleeName(tree, call) orelse return false;
    return std.mem.eql(u8, name, "Number") or
        std.mem.eql(u8, name, "parseInt") or
        std.mem.eql(u8, name, "parseFloat");
}

fn callCalleeName(tree: *const ast.Tree, call: ast.CallExpression) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    message: []const u8,
) Allocator.Error!void {
    try core.addDiagnostic(allocator, diagnostics, .warning, id, message, tree.span(index));
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
