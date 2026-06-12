const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-extra-bind";

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
    if (!std.mem.eql(u8, method, "bind")) return;

    const target = unwrapTransparent(tree, callee_member.object);
    const has_bound_arguments = call.arguments.len > 1;

    const is_extra = switch (tree.data(target)) {
        .arrow_function_expression => true,
        .function => |function| !has_bound_arguments and !functionUsesThis(tree, function),
        else => false,
    };
    if (!is_extra) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "The function binding is unnecessary.",
        tree.span(index),
    );
}

fn functionUsesThis(tree: *const ast.Tree, function: ast.Function) bool {
    if (function.body == .null) return false;

    const body = switch (tree.data(function.body)) {
        .function_body => |body| body,
        else => return false,
    };
    return rangeUsesThis(tree, body.body);
}

fn rangeUsesThis(tree: *const ast.Tree, range: ast.IndexRange) bool {
    for (tree.extra(range)) |child| {
        if (nodeUsesThis(tree, child)) return true;
    }
    return false;
}

fn nodeUsesThis(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .this_expression => true,
        .function,
        .class,
        .arrow_function_expression,
        => false,
        .expression_statement => |statement| nodeUsesThis(tree, statement.expression),
        .return_statement => |statement| nodeUsesThis(tree, statement.argument),
        .throw_statement => |statement| nodeUsesThis(tree, statement.argument),
        .block_statement => |block| rangeUsesThis(tree, block.body),
        .static_block => |block| rangeUsesThis(tree, block.body),
        .if_statement => |statement| nodeUsesThis(tree, statement.@"test") or
            nodeUsesThis(tree, statement.consequent) or
            nodeUsesThis(tree, statement.alternate),
        .while_statement => |statement| nodeUsesThis(tree, statement.@"test") or
            nodeUsesThis(tree, statement.body),
        .do_while_statement => |statement| nodeUsesThis(tree, statement.@"test") or
            nodeUsesThis(tree, statement.body),
        .for_statement => |statement| nodeUsesThis(tree, statement.init) or
            nodeUsesThis(tree, statement.@"test") or
            nodeUsesThis(tree, statement.update) or
            nodeUsesThis(tree, statement.body),
        .for_in_statement => |statement| nodeUsesThis(tree, statement.left) or
            nodeUsesThis(tree, statement.right) or
            nodeUsesThis(tree, statement.body),
        .for_of_statement => |statement| nodeUsesThis(tree, statement.left) or
            nodeUsesThis(tree, statement.right) or
            nodeUsesThis(tree, statement.body),
        .switch_statement => |statement| {
            if (nodeUsesThis(tree, statement.discriminant)) return true;
            for (tree.extra(statement.cases)) |case_index| {
                if (nodeUsesThis(tree, case_index)) return true;
            }
            return false;
        },
        .switch_case => |switch_case| nodeUsesThis(tree, switch_case.@"test") or
            rangeUsesThis(tree, switch_case.consequent),
        .try_statement => |statement| nodeUsesThis(tree, statement.block) or
            nodeUsesThis(tree, statement.handler) or
            nodeUsesThis(tree, statement.finalizer),
        .catch_clause => |clause| nodeUsesThis(tree, clause.body),
        .labeled_statement => |statement| nodeUsesThis(tree, statement.body),
        .with_statement => |statement| nodeUsesThis(tree, statement.object) or
            nodeUsesThis(tree, statement.body),
        .variable_declaration => |declaration| {
            for (tree.extra(declaration.declarators)) |declarator| {
                if (nodeUsesThis(tree, declarator)) return true;
            }
            return false;
        },
        .variable_declarator => |declarator| nodeUsesThis(tree, declarator.init),
        .parenthesized_expression => |expression| nodeUsesThis(tree, expression.expression),
        .chain_expression => |expression| nodeUsesThis(tree, expression.expression),
        .member_expression => |expression| nodeUsesThis(tree, expression.object) or
            nodeUsesThis(tree, expression.property),
        .call_expression => |expression| nodeUsesThis(tree, expression.callee) or
            rangeUsesThis(tree, expression.arguments),
        .new_expression => |expression| nodeUsesThis(tree, expression.callee) or
            rangeUsesThis(tree, expression.arguments),
        .assignment_expression => |expression| nodeUsesThis(tree, expression.left) or
            nodeUsesThis(tree, expression.right),
        .binary_expression => |expression| nodeUsesThis(tree, expression.left) or
            nodeUsesThis(tree, expression.right),
        .logical_expression => |expression| nodeUsesThis(tree, expression.left) or
            nodeUsesThis(tree, expression.right),
        .conditional_expression => |expression| nodeUsesThis(tree, expression.@"test") or
            nodeUsesThis(tree, expression.consequent) or
            nodeUsesThis(tree, expression.alternate),
        .unary_expression => |expression| nodeUsesThis(tree, expression.argument),
        .update_expression => |expression| nodeUsesThis(tree, expression.argument),
        .await_expression => |expression| nodeUsesThis(tree, expression.argument),
        .yield_expression => |expression| nodeUsesThis(tree, expression.argument),
        .sequence_expression => |expression| rangeUsesThis(tree, expression.expressions),
        .array_expression => |expression| rangeUsesThis(tree, expression.elements),
        .object_expression => |expression| rangeUsesThis(tree, expression.properties),
        .object_property => |property| nodeUsesThis(tree, property.key) or nodeUsesThis(tree, property.value),
        .spread_element => |element| nodeUsesThis(tree, element.argument),
        else => false,
    };
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
