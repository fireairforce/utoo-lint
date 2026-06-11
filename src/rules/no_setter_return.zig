const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-setter-return";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ReturnStatement,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (statement.argument == .null) return;
    if (!isInsideSetterBody(tree, ctx)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected return of a value in setter.",
        tree.span(index),
    );
}

fn isInsideSetterBody(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .arrow_function_expression => return false,
            .function => {
                const parent = ctx.path.ancestor(depth + 1) orelse return false;
                return switch (tree.data(parent)) {
                    .method_definition => |method| method.kind == .set and method.value == ancestor,
                    .object_property => |property| isSetterProperty(tree, ctx, property, ancestor, depth + 1),
                    else => false,
                };
            },
            else => {},
        }
    }

    return false;
}

fn isSetterProperty(
    tree: *const ast.Tree,
    ctx: *traverser.basic.Ctx,
    property: ast.ObjectProperty,
    function_index: ast.NodeIndex,
    property_depth: usize,
) bool {
    if (property.value != function_index) return false;
    if (property.kind == .set) return true;

    if (!isPropertyNamed(tree, property, "set")) return false;
    const object_index = ctx.path.ancestor(property_depth + 1) orelse return false;
    return isPropertyDescriptorContext(tree, ctx, object_index, property_depth + 1);
}

fn isPropertyDescriptorContext(
    tree: *const ast.Tree,
    ctx: *traverser.basic.Ctx,
    object_index: ast.NodeIndex,
    object_depth: usize,
) bool {
    if (isDefinePropertyDescriptor(tree, ctx, object_index, object_depth)) return true;
    if (isNestedDescriptorObject(tree, ctx, object_index, object_depth)) return true;
    return false;
}

fn isDefinePropertyDescriptor(
    tree: *const ast.Tree,
    ctx: *traverser.basic.Ctx,
    object_index: ast.NodeIndex,
    object_depth: usize,
) bool {
    const parent = ctx.path.ancestor(object_depth + 1) orelse return false;
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
    object_depth: usize,
) bool {
    const property_index = ctx.path.ancestor(object_depth + 1) orelse return false;
    const property = switch (tree.data(property_index)) {
        .object_property => |property| property,
        else => return false,
    };
    if (property.value != object_index) return false;

    const descriptors_object = ctx.path.ancestor(object_depth + 2) orelse return false;
    const call_index = ctx.path.ancestor(object_depth + 3) orelse return false;
    const call = switch (tree.data(call_index)) {
        .call_expression => |call| call,
        else => return false,
    };

    const arguments = tree.extra(call.arguments);
    if (arguments.len < 2 or arguments[1] != descriptors_object) return false;
    return isStaticMemberCall(tree, call.callee, "Object", "create") or
        isStaticMemberCall(tree, call.callee, "Object", "defineProperties");
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
