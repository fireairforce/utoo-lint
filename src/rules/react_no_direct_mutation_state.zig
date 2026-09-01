const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "react/no-direct-mutation-state";

const message = "Do not mutate state directly. Use setState().";

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    const left = unwrapTransparent(tree, expression.left);
    const member = switch (tree.data(left)) {
        .member_expression => |member| member,
        else => return,
    };
    if (stateRoot(tree, left) == null) return;
    const component = componentAncestor(tree, ctx) orelse return;
    if (isAllowedConstructorMutation(tree, ctx, component)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        message,
        tree.span(unwrapTransparent(tree, member.object)),
    );
}

pub fn checkUpdateExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.UpdateExpression,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    const root = stateRoot(tree, expression.argument) orelse return;
    const component = componentAncestor(tree, ctx) orelse return;
    if (isAllowedConstructorMutation(tree, ctx, component)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        message,
        tree.span(root),
    );
}

fn stateRoot(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.NodeIndex {
    var current = unwrapTransparent(tree, index);
    while (current != .null) {
        const member = switch (tree.data(current)) {
            .member_expression => |member| member,
            else => return null,
        };
        const object = unwrapTransparent(tree, member.object);
        if (tree.data(object) == .member_expression) {
            current = object;
            continue;
        }
        if (!isThisExpression(tree, object)) return null;
        const property = identifierPropertyName(tree, member.property) orelse return null;
        return if (std.mem.eql(u8, property, "state")) current else null;
    }
    return null;
}

fn componentAncestor(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) ?ast.NodeIndex {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .class => |class| return if (isReactComponentClass(tree, class)) ancestor else null,
            .object_expression => if (isCreateClassObject(tree, ancestor, ctx.path.ancestor(depth + 1))) return ancestor,
            else => {},
        }
    }
    return null;
}

fn isAllowedConstructorMutation(
    tree: *const ast.Tree,
    ctx: *traverser.basic.Ctx,
    component: ast.NodeIndex,
) bool {
    if (tree.data(component) != .class) return false;

    var inside_call = false;
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        if (ancestor == component) return false;
        switch (tree.data(ancestor)) {
            .call_expression => inside_call = true,
            .method_definition => |method| return method.kind == .constructor and !inside_call,
            else => {},
        }
    }
    return false;
}

fn isCreateClassObject(tree: *const ast.Tree, index: ast.NodeIndex, parent_index: ?ast.NodeIndex) bool {
    const parent = parent_index orelse return false;
    const call = switch (tree.data(parent)) {
        .call_expression => |call| call,
        else => return false,
    };
    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0 or arguments[0] != index) return false;
    return isCreateClassCallee(tree, call.callee);
}

fn isCreateClassCallee(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const callee = unwrapTransparent(tree, index);
    if (identifierReferenceName(tree, callee)) |name| {
        return std.mem.eql(u8, name, "createReactClass");
    }

    const member = switch (tree.data(callee)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;
    if (!identifierReferenceEquals(tree, unwrapTransparent(tree, member.object), "React")) return false;
    const property = identifierPropertyName(tree, member.property) orelse return false;
    return std.mem.eql(u8, property, "createClass");
}

fn isReactComponentClass(tree: *const ast.Tree, class: ast.Class) bool {
    if (class.super_class == .null) return false;
    const super_class = unwrapTransparent(tree, class.super_class);

    if (identifierReferenceName(tree, super_class)) |name| {
        return std.mem.eql(u8, name, "Component") or std.mem.eql(u8, name, "PureComponent");
    }

    const member = switch (tree.data(super_class)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed) return false;
    if (!identifierReferenceEquals(tree, unwrapTransparent(tree, member.object), "React")) return false;
    const property = identifierPropertyName(tree, member.property) orelse return false;
    return std.mem.eql(u8, property, "Component") or std.mem.eql(u8, property, "PureComponent");
}

fn isThisExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return tree.data(index) == .this_expression;
}

fn identifierPropertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
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
