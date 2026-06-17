const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "new-cap";

pub const Options = struct {
    new_is_cap: bool = true,
    cap_is_new: bool = true,
};

pub fn checkNewExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NewExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    return checkNewExpressionWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkNewExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NewExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (!options.new_is_cap) return;

    const name = constructorName(tree, expression.callee) orelse return;
    if (nameCase(name) != .lower) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "A constructor name should not start with a lowercase letter.",
        tree.span(index),
    );
}

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.CallExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    return checkCallExpressionWithOptions(allocator, diagnostics, tree, expression, index, .{});
}

pub fn checkCallExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.CallExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (!options.cap_is_new) return;

    const callee = unwrapTransparent(tree, expression.callee);
    const name = constructorName(tree, callee) orelse return;
    if (nameCase(name) != .upper) return;
    if (isAllowedCallableBuiltin(tree, callee, name)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "A function with a name starting with an uppercase letter should only be used as a constructor.",
        tree.span(index),
    );
}

fn constructorName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .member_expression => |member| propertyName(tree, member),
        else => null,
    };
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

fn isAllowedCallableBuiltin(tree: *const ast.Tree, callee: ast.NodeIndex, name: []const u8) bool {
    if (tree.data(callee) != .identifier_reference) return false;

    const builtins = [_][]const u8{
        "Array",
        "BigInt",
        "Boolean",
        "Date",
        "Error",
        "Number",
        "Object",
        "RegExp",
        "String",
        "Symbol",
    };

    for (builtins) |builtin| {
        if (std.mem.eql(u8, name, builtin)) return true;
    }

    return false;
}

const NameCase = enum {
    upper,
    lower,
    other,
};

fn nameCase(name: []const u8) NameCase {
    if (name.len == 0) return .other;
    if (std.ascii.isUpper(name[0])) return .upper;
    if (std.ascii.isLower(name[0])) return .lower;
    return .other;
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
