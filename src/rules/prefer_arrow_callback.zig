const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "prefer-arrow-callback";

pub const Options = struct {
    allow_named_functions: bool = false,
    allow_unbound_this: bool = true,
};

pub fn checkFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (function.type != .function_expression) return;
    if (function.generator) return;
    if (!isCallback(tree, index, &ctx.path)) return;
    if (options.allow_named_functions and function.id != .null) return;
    if (options.allow_unbound_this and !isBoundCallback(tree, index, &ctx.path) and nodeUsesThisOrSuper(tree, function.body)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Expected an arrow function.",
        tree.span(index),
    );
}

fn isCallback(tree: *const ast.Tree, index: ast.NodeIndex, path: *const traverser.NodePath) bool {
    if (isCallOrNewArgument(tree, index, path.parent())) return true;

    if (!isBindMemberObject(tree, index, path.parent())) return false;
    const member_index = path.parent() orelse return false;
    const bind_call_index = path.ancestor(2) orelse return false;
    if (!isCallCallee(tree, bind_call_index, member_index)) return false;

    return isCallOrNewArgument(tree, bind_call_index, path.ancestor(3));
}

fn isBoundCallback(tree: *const ast.Tree, index: ast.NodeIndex, path: *const traverser.NodePath) bool {
    if (!isBindMemberObject(tree, index, path.parent())) return false;
    const member_index = path.parent() orelse return false;
    const bind_call_index = path.ancestor(2) orelse return false;
    return isCallCallee(tree, bind_call_index, member_index);
}

fn isCallOrNewArgument(tree: *const ast.Tree, index: ast.NodeIndex, parent_index: ?ast.NodeIndex) bool {
    const parent = parent_index orelse return false;
    const arguments = switch (tree.data(parent)) {
        .call_expression => |call| if (call.callee == index) return false else call.arguments,
        .new_expression => |new| if (new.callee == index) return false else new.arguments,
        else => return false,
    };
    return rangeContains(tree, arguments, index);
}

fn isCallCallee(tree: *const ast.Tree, call_index: ast.NodeIndex, callee_index: ast.NodeIndex) bool {
    return switch (tree.data(call_index)) {
        .call_expression => |call| call.callee == callee_index,
        else => false,
    };
}

fn isBindMemberObject(tree: *const ast.Tree, index: ast.NodeIndex, parent_index: ?ast.NodeIndex) bool {
    const parent = parent_index orelse return false;
    const member = switch (tree.data(parent)) {
        .member_expression => |member| member,
        else => return false,
    };
    const property = propertyName(tree, member) orelse return false;
    return member.object == index and std.mem.eql(u8, property, "bind");
}

fn propertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;
    return if (member.computed)
        switch (tree.data(member.property)) {
            .string_literal => |literal| tree.string(literal.value),
            else => null,
        }
    else switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn rangeContains(tree: *const ast.Tree, range: ast.IndexRange, index: ast.NodeIndex) bool {
    for (tree.extra(range)) |child| {
        if (child == index) return true;
    }
    return false;
}

fn nodeUsesThisOrSuper(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .this_expression, .super => true,
        .function, .class => false,
        .arrow_function_expression => |arrow| nodeUsesThisOrSuper(tree, arrow.body),
        .function_body => |body| rangeUsesThisOrSuper(tree, body.body),
        .expression_statement => |statement| nodeUsesThisOrSuper(tree, statement.expression),
        .return_statement => |statement| nodeUsesThisOrSuper(tree, statement.argument),
        .block_statement => |block| rangeUsesThisOrSuper(tree, block.body),
        .parenthesized_expression => |expression| nodeUsesThisOrSuper(tree, expression.expression),
        .chain_expression => |expression| nodeUsesThisOrSuper(tree, expression.expression),
        .member_expression => |expression| nodeUsesThisOrSuper(tree, expression.object) or
            nodeUsesThisOrSuper(tree, expression.property),
        .call_expression => |expression| nodeUsesThisOrSuper(tree, expression.callee) or
            rangeUsesThisOrSuper(tree, expression.arguments),
        .assignment_expression => |expression| nodeUsesThisOrSuper(tree, expression.left) or
            nodeUsesThisOrSuper(tree, expression.right),
        .binary_expression => |expression| nodeUsesThisOrSuper(tree, expression.left) or
            nodeUsesThisOrSuper(tree, expression.right),
        .logical_expression => |expression| nodeUsesThisOrSuper(tree, expression.left) or
            nodeUsesThisOrSuper(tree, expression.right),
        .conditional_expression => |expression| nodeUsesThisOrSuper(tree, expression.@"test") or
            nodeUsesThisOrSuper(tree, expression.consequent) or
            nodeUsesThisOrSuper(tree, expression.alternate),
        .unary_expression => |expression| nodeUsesThisOrSuper(tree, expression.argument),
        .update_expression => |expression| nodeUsesThisOrSuper(tree, expression.argument),
        .await_expression => |expression| nodeUsesThisOrSuper(tree, expression.argument),
        .yield_expression => |expression| nodeUsesThisOrSuper(tree, expression.argument),
        .sequence_expression => |expression| rangeUsesThisOrSuper(tree, expression.expressions),
        .array_expression => |expression| rangeUsesThisOrSuper(tree, expression.elements),
        .object_expression => |expression| rangeUsesThisOrSuper(tree, expression.properties),
        .object_property => |property| nodeUsesThisOrSuper(tree, property.key) or
            nodeUsesThisOrSuper(tree, property.value),
        .spread_element => |element| nodeUsesThisOrSuper(tree, element.argument),
        else => false,
    };
}

fn rangeUsesThisOrSuper(tree: *const ast.Tree, range: ast.IndexRange) bool {
    for (tree.extra(range)) |child| {
        if (nodeUsesThisOrSuper(tree, child)) return true;
    }
    return false;
}
