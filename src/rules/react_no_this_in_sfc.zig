const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "react/no-this-in-sfc";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (tree.data(unwrapTransparent(tree, member.object)) != .this_expression) return;
    if (parentStatelessComponent(tree, ctx) == null) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Stateless functional components should not use `this`",
        tree.span(index),
    );
}

fn parentStatelessComponent(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) ?ast.NodeIndex {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .function => |function| {
                if (isStatelessFunctionComponent(tree, function, ancestor, ctx.path.ancestor(depth + 1))) return ancestor;
            },
            .arrow_function_expression => |arrow| {
                if (isStatelessArrowComponent(tree, arrow, ancestor, ctx.path.ancestor(depth + 1))) return ancestor;
            },
            .class => return null,
            else => {},
        }
    }
    return null;
}

fn isStatelessFunctionComponent(
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
    parent_index: ?ast.NodeIndex,
) bool {
    if (function.async and function.generator) return false;
    if (!functionReturnsJSXOrNull(tree, index)) return false;

    if (function.type == .function_declaration) {
        const name = bindingIdentifierName(tree, function.id) orelse return true;
        return startsUppercase(name);
    }

    return functionExpressionHasComponentParent(tree, parent_index);
}

fn isStatelessArrowComponent(
    tree: *const ast.Tree,
    arrow: ast.ArrowFunctionExpression,
    index: ast.NodeIndex,
    parent_index: ?ast.NodeIndex,
) bool {
    _ = arrow;
    if (!functionReturnsJSXOrNull(tree, index)) return false;
    return functionExpressionHasComponentParent(tree, parent_index);
}

fn functionExpressionHasComponentParent(tree: *const ast.Tree, parent_index: ?ast.NodeIndex) bool {
    const parent = parent_index orelse return false;
    return switch (tree.data(parent)) {
        .variable_declarator => |declarator| identifierBindingStartsUppercase(tree, declarator.id),
        .assignment_expression => |expression| identifierReferenceStartsUppercase(tree, expression.left),
        .export_default_declaration => true,
        .object_property => false,
        else => false,
    };
}

fn functionReturnsJSXOrNull(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .function => |function| function.body != .null and bodyReturnsJSXOrNull(tree, function.body),
        .arrow_function_expression => |arrow| if (arrow.expression)
            isJSXOrNullValue(tree, arrow.body)
        else
            bodyReturnsJSXOrNull(tree, arrow.body),
        else => false,
    };
}

fn bodyReturnsJSXOrNull(tree: *const ast.Tree, body_index: ast.NodeIndex) bool {
    const range = switch (tree.data(body_index)) {
        .function_body => |body| body.body,
        .block_statement => |block| block.body,
        else => return false,
    };
    return rangeReturnsJSXOrNull(tree, range);
}

fn rangeReturnsJSXOrNull(tree: *const ast.Tree, range: ast.IndexRange) bool {
    for (tree.extra(range)) |statement_index| {
        if (statementReturnsJSXOrNull(tree, statement_index)) return true;
    }
    return false;
}

fn statementReturnsJSXOrNull(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .return_statement => |statement| isJSXOrNullValue(tree, statement.argument),
        .block_statement => |block| rangeReturnsJSXOrNull(tree, block.body),
        .if_statement => |statement| statementReturnsJSXOrNull(tree, statement.consequent) or
            statementReturnsJSXOrNull(tree, statement.alternate),
        .switch_statement => |statement| {
            for (tree.extra(statement.cases)) |case_index| {
                const case = switch (tree.data(case_index)) {
                    .switch_case => |case| case,
                    else => continue,
                };
                if (rangeReturnsJSXOrNull(tree, case.consequent)) return true;
            }
            return false;
        },
        .function,
        .arrow_function_expression,
        => false,
        else => false,
    };
}

fn isJSXOrNullValue(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .jsx_element,
        .jsx_fragment,
        .null_literal,
        => true,
        .call_expression => |call| isCreateElementCall(tree, call),
        .conditional_expression => |conditional| isJSXOrNullValue(tree, conditional.consequent) or
            isJSXOrNullValue(tree, conditional.alternate),
        .logical_expression => |logical| isJSXOrNullValue(tree, logical.left) or isJSXOrNullValue(tree, logical.right),
        .sequence_expression => |sequence| {
            if (sequence.expressions.len == 0) return false;
            const items = tree.extra(sequence.expressions);
            return isJSXOrNullValue(tree, items[items.len - 1]);
        },
        else => false,
    };
}

fn isCreateElementCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const callee = unwrapTransparent(tree, call.callee);
    if (identifierReferenceName(tree, callee)) |name| {
        return std.mem.eql(u8, name, "createElement");
    }

    const member = switch (tree.data(callee)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;
    if (!identifierReferenceEquals(tree, unwrapTransparent(tree, member.object), "React")) return false;
    const property = propertyName(tree, member.property) orelse return false;
    return std.mem.eql(u8, property, "createElement");
}

fn identifierBindingStartsUppercase(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const name = bindingIdentifierName(tree, index) orelse return false;
    return startsUppercase(name);
}

fn identifierReferenceStartsUppercase(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const name = identifierReferenceName(tree, unwrapTransparent(tree, index)) orelse return false;
    return startsUppercase(name);
}

fn startsUppercase(name: []const u8) bool {
    return name.len > 0 and std.ascii.isUpper(name[0]);
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn identifierReferenceEquals(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    const name = identifierReferenceName(tree, index) orelse return false;
    return std.mem.eql(u8, name, expected);
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
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
