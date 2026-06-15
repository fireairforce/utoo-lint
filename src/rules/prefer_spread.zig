const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "prefer-spread";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (call.optional) return;

    const callee_member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return,
    };
    if (callee_member.optional) return;

    const method = propertyName(tree, callee_member) orelse return;
    if (!std.mem.eql(u8, method, "apply")) return;

    const arguments = tree.extra(call.arguments);
    if (arguments.len != 2) return;
    if (!canPreserveThisArg(tree, callee_member.object, arguments[0])) return;
    if (!isSpreadableArgument(tree, arguments[1])) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Use spread syntax instead of apply().",
        tree.span(index),
    );
}

fn canPreserveThisArg(tree: *const ast.Tree, target: ast.NodeIndex, this_arg: ast.NodeIndex) bool {
    const target_member = switch (tree.data(unwrapTransparent(tree, target))) {
        .member_expression => |member| member,
        else => return isNullOrUndefined(tree, this_arg),
    };

    if (target_member.optional) return false;
    if (!isSimpleReference(tree, target_member.object)) return false;
    return sameSource(tree, target_member.object, this_arg);
}

fn isSpreadableArgument(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .array_expression,
        .spread_element,
        => false,
        else => true,
    };
}

fn isNullOrUndefined(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .null_literal => true,
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), "undefined"),
        else => false,
    };
}

fn isSimpleReference(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference,
        .this_expression,
        => true,
        .member_expression => |member| !member.optional and isSimpleReference(tree, member.object) and propertyName(tree, member) != null,
        else => false,
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

fn sameSource(tree: *const ast.Tree, left: ast.NodeIndex, right: ast.NodeIndex) bool {
    const left_source = sourceSlice(tree, unwrapTransparent(tree, left)) orelse return false;
    const right_source = sourceSlice(tree, unwrapTransparent(tree, right)) orelse return false;

    return std.mem.eql(u8, left_source, right_source);
}

fn sourceSlice(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);

    if (start >= end or end > tree.source.len) return null;
    return tree.source[start..end];
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
