const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "getter-return";

const Completion = enum {
    continues,
    valid_terminal,
    invalid_return,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.FunctionBody,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (!isGetterBody(tree, ctx)) return;
    if (rangeAlwaysReturnsValue(tree, body.body)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Expected to return a value in getter.",
        tree.span(index),
    );
}

fn isGetterBody(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    const function_index = ctx.path.ancestor(1) orelse return false;
    if (tree.data(function_index) != .function) return false;

    const parent = ctx.path.ancestor(2) orelse return false;
    return switch (tree.data(parent)) {
        .method_definition => |method| method.kind == .get and method.value == function_index,
        .object_property => |property| isGetterProperty(tree, ctx, property, function_index),
        else => false,
    };
}

fn isGetterProperty(
    tree: *const ast.Tree,
    ctx: *traverser.basic.Ctx,
    property: ast.ObjectProperty,
    function_index: ast.NodeIndex,
) bool {
    if (property.value != function_index) return false;
    if (property.kind == .get) return true;

    if (!isPropertyNamed(tree, property, "get")) return false;
    const object_index = ctx.path.ancestor(3) orelse return false;
    return isPropertyDescriptorContext(tree, ctx, object_index);
}

fn isPropertyDescriptorContext(
    tree: *const ast.Tree,
    ctx: *traverser.basic.Ctx,
    object_index: ast.NodeIndex,
) bool {
    if (isDefinePropertyDescriptor(tree, ctx, object_index)) return true;
    if (isNestedDescriptorObject(tree, ctx, object_index)) return true;
    return false;
}

fn isDefinePropertyDescriptor(
    tree: *const ast.Tree,
    ctx: *traverser.basic.Ctx,
    object_index: ast.NodeIndex,
) bool {
    const parent = ctx.path.ancestor(4) orelse return false;
    const call = switch (tree.data(parent)) {
        .call_expression => |call| call,
        else => return false,
    };

    const arguments = tree.extra(call.arguments);
    if (arguments.len < 3 or arguments[2] != object_index) return false;
    return isStaticMemberCall(tree, call.callee, "Object", "defineProperty");
}

fn isNestedDescriptorObject(
    tree: *const ast.Tree,
    ctx: *traverser.basic.Ctx,
    object_index: ast.NodeIndex,
) bool {
    const property_index = ctx.path.ancestor(4) orelse return false;
    const property = switch (tree.data(property_index)) {
        .object_property => |property| property,
        else => return false,
    };
    if (property.value != object_index) return false;

    const descriptors_object = ctx.path.ancestor(5) orelse return false;
    const call_index = ctx.path.ancestor(6) orelse return false;
    const call = switch (tree.data(call_index)) {
        .call_expression => |call| call,
        else => return false,
    };

    const arguments = tree.extra(call.arguments);
    if (arguments.len < 2 or arguments[1] != descriptors_object) return false;
    return isStaticMemberCall(tree, call.callee, "Object", "create") or
        isStaticMemberCall(tree, call.callee, "Object", "defineProperties");
}

fn rangeAlwaysReturnsValue(tree: *const ast.Tree, range: ast.IndexRange) bool {
    return rangeCompletion(tree, range) == .valid_terminal;
}

fn rangeCompletion(tree: *const ast.Tree, range: ast.IndexRange) Completion {
    for (tree.extra(range)) |statement| {
        switch (statementCompletion(tree, statement)) {
            .continues => {},
            .valid_terminal => return .valid_terminal,
            .invalid_return => return .invalid_return,
        }
    }

    return .continues;
}

fn statementCompletion(tree: *const ast.Tree, index: ast.NodeIndex) Completion {
    if (index == .null) return .continues;

    return switch (tree.data(index)) {
        .return_statement => |statement| if (statement.argument != .null) .valid_terminal else .invalid_return,
        .throw_statement => .valid_terminal,
        .block_statement => |block| rangeCompletion(tree, block.body),
        .if_statement => |statement| ifCompletion(tree, statement),
        .try_statement => |statement| tryCompletion(tree, statement),
        else => .continues,
    };
}

fn ifCompletion(tree: *const ast.Tree, statement: ast.IfStatement) Completion {
    const consequent = statementCompletion(tree, statement.consequent);
    if (consequent == .invalid_return) return .invalid_return;

    if (statement.alternate == .null) return .continues;
    const alternate = statementCompletion(tree, statement.alternate);
    if (alternate == .invalid_return) return .invalid_return;

    if (consequent == .valid_terminal and alternate == .valid_terminal) return .valid_terminal;
    return .continues;
}

fn tryCompletion(tree: *const ast.Tree, statement: ast.TryStatement) Completion {
    if (statement.finalizer != .null) {
        const finalizer = statementCompletion(tree, statement.finalizer);
        if (finalizer != .continues) return finalizer;
    }

    const block = statementCompletion(tree, statement.block);
    if (block == .invalid_return) return .invalid_return;
    if (statement.handler == .null) return block;

    const handler_node = switch (tree.data(statement.handler)) {
        .catch_clause => |handler| handler.body,
        else => return .continues,
    };
    const handler = statementCompletion(tree, handler_node);
    if (handler == .invalid_return) return .invalid_return;

    if (block == .valid_terminal and handler == .valid_terminal) return .valid_terminal;
    return .continues;
}

fn isStaticMemberCall(tree: *const ast.Tree, callee: ast.NodeIndex, object_name: []const u8, property_name: []const u8) bool {
    const member = switch (tree.data(unwrapTransparent(tree, callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;

    return isIdentifierReferenceNamed(tree, member.object, object_name) and
        isIdentifierNameNamed(tree, member.property, property_name);
}

fn isPropertyNamed(tree: *const ast.Tree, property: ast.ObjectProperty, name: []const u8) bool {
    if (property.computed) return false;

    return switch (tree.data(property.key)) {
        .identifier_name => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        .string_literal => |literal| std.mem.eql(u8, tree.string(literal.value), name),
        else => false,
    };
}

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
    };
}

fn isIdentifierNameNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .identifier_name => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
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
