const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "array-callback-return";

pub const Options = struct {
    allow_implicit: bool = true,
};

const Completion = enum {
    continues,
    valid_terminal,
    invalid_return,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    _: ast.NodeIndex,
) Allocator.Error!void {
    return checkWithOptions(allocator, diagnostics, tree, call, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    options: Options,
) Allocator.Error!void {
    const callback = callbackArgument(tree, call) orelse return;
    if (callbackReturnsValue(tree, callback, options)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Expected to return a value in array callback.",
        tree.span(callback),
    );
}

fn callbackArgument(tree: *const ast.Tree, call: ast.CallExpression) ?ast.NodeIndex {
    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0) return null;

    const callee = unwrapTransparent(tree, call.callee);
    const member = switch (tree.data(callee)) {
        .member_expression => |member| member,
        else => return null,
    };

    const method = propertyName(tree, member) orelse return null;
    if (std.mem.eql(u8, method, "forEach")) return null;

    if (isArrayFromCall(tree, member, method)) {
        if (arguments.len < 2) return null;
        return callbackIfFunction(tree, arguments[1]);
    }

    if (!isArrayCallbackMethod(method)) return null;
    return callbackIfFunction(tree, arguments[0]);
}

fn callbackIfFunction(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.NodeIndex {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .function,
        .arrow_function_expression,
        => unwrapTransparent(tree, index),
        else => null,
    };
}

fn isArrayFromCall(tree: *const ast.Tree, member: ast.MemberExpression, method: []const u8) bool {
    return std.mem.eql(u8, method, "from") and isIdentifierReferenceNamed(tree, member.object, "Array");
}

fn isArrayCallbackMethod(method: []const u8) bool {
    const methods = [_][]const u8{
        "every",
        "filter",
        "find",
        "findIndex",
        "findLast",
        "findLastIndex",
        "flatMap",
        "map",
        "reduce",
        "reduceRight",
        "some",
        "sort",
        "toSorted",
    };

    for (methods) |candidate| {
        if (std.mem.eql(u8, method, candidate)) return true;
    }

    return false;
}

fn callbackReturnsValue(tree: *const ast.Tree, callback: ast.NodeIndex, options: Options) bool {
    return switch (tree.data(callback)) {
        .function => |function| functionReturnsValue(tree, function.body, options),
        .arrow_function_expression => |arrow| if (arrow.expression)
            !isVoidExpression(tree, arrow.body)
        else
            functionReturnsValue(tree, arrow.body, options),
        else => true,
    };
}

fn functionReturnsValue(tree: *const ast.Tree, body_index: ast.NodeIndex, options: Options) bool {
    if (body_index == .null) return true;

    const body = switch (tree.data(body_index)) {
        .function_body => |body| body,
        else => return true,
    };

    return rangeCompletion(tree, body.body, options) == .valid_terminal;
}

fn rangeCompletion(tree: *const ast.Tree, range: ast.IndexRange, options: Options) Completion {
    for (tree.extra(range)) |statement| {
        switch (statementCompletion(tree, statement, options)) {
            .continues => {},
            .valid_terminal => return .valid_terminal,
            .invalid_return => return .invalid_return,
        }
    }

    return .continues;
}

fn statementCompletion(tree: *const ast.Tree, index: ast.NodeIndex, options: Options) Completion {
    if (index == .null) return .continues;

    return switch (tree.data(index)) {
        .return_statement => |statement| returnCompletion(tree, statement, options),
        .throw_statement => .valid_terminal,
        .block_statement => |block| rangeCompletion(tree, block.body, options),
        .if_statement => |statement| ifCompletion(tree, statement, options),
        .try_statement => |statement| tryCompletion(tree, statement, options),
        else => .continues,
    };
}

fn returnCompletion(tree: *const ast.Tree, statement: ast.ReturnStatement, options: Options) Completion {
    if (statement.argument == .null) return if (options.allow_implicit)
        .valid_terminal
    else
        .invalid_return;
    if (isVoidExpression(tree, statement.argument)) return .invalid_return;
    return .valid_terminal;
}

fn ifCompletion(tree: *const ast.Tree, statement: ast.IfStatement, options: Options) Completion {
    const consequent = statementCompletion(tree, statement.consequent, options);
    if (consequent == .invalid_return) return .invalid_return;

    if (statement.alternate == .null) return .continues;
    const alternate = statementCompletion(tree, statement.alternate, options);
    if (alternate == .invalid_return) return .invalid_return;

    if (consequent == .valid_terminal and alternate == .valid_terminal) return .valid_terminal;
    return .continues;
}

fn tryCompletion(tree: *const ast.Tree, statement: ast.TryStatement, options: Options) Completion {
    if (statement.finalizer != .null) {
        const finalizer = statementCompletion(tree, statement.finalizer, options);
        if (finalizer != .continues) return finalizer;
    }

    const block = statementCompletion(tree, statement.block, options);
    if (block == .invalid_return) return .invalid_return;
    if (statement.handler == .null) return block;

    const handler_node = switch (tree.data(statement.handler)) {
        .catch_clause => |handler| handler.body,
        else => return .continues,
    };
    const handler = statementCompletion(tree, handler_node, options);
    if (handler == .invalid_return) return .invalid_return;

    if (block == .valid_terminal and handler == .valid_terminal) return .valid_terminal;
    return .continues;
}

fn isVoidExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .unary_expression => |expression| expression.operator == .void,
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

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    if (index == .null) return false;
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
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
