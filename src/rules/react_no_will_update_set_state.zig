const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "react/no-will-update-set-state";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    const callee = unwrapTransparent(tree, call.callee);
    if (!isThisSetStateCall(tree, callee)) return;

    const method_name = lifecycleAncestorName(tree, ctx) orelse return;
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(callee),
        "Do not use setState in {s}",
        .{method_name},
    );
}

fn lifecycleAncestorName(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) ?[]const u8 {
    var depth: usize = 0;
    var ancestor_depth: usize = 1;
    while (ctx.path.ancestor(ancestor_depth)) |ancestor| : (ancestor_depth += 1) {
        switch (tree.data(ancestor)) {
            .function => |function| {
                if (function.type == .function_expression or function.type == .function_declaration) {
                    depth += 1;
                }
            },
            .method_definition => |method| {
                const name = methodName(tree, method.key, method.computed) orelse continue;
                if (isLifecycleName(name) and depth <= 1) return name;
            },
            .object_property => |property| {
                const name = propertyName(tree, property.key, property.computed) orelse continue;
                if (isLifecycleName(name) and depth <= 1) return name;
            },
            .property_definition => |property| {
                const name = propertyName(tree, property.key, property.computed) orelse continue;
                if (isLifecycleName(name) and depth <= 1) return name;
            },
            else => {},
        }
    }
    return null;
}

fn isLifecycleName(name: []const u8) bool {
    return std.mem.eql(u8, name, "componentWillUpdate") or
        std.mem.eql(u8, name, "UNSAFE_componentWillUpdate");
}

fn isThisSetStateCall(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const member = switch (tree.data(index)) {
        .member_expression => |member| member,
        else => return false,
    };

    if (member.computed) return false;
    if (tree.data(unwrapTransparent(tree, member.object)) != .this_expression) return false;
    const name = propertyName(tree, member.property, false) orelse return false;
    return std.mem.eql(u8, name, "setState");
}

fn methodName(tree: *const ast.Tree, key: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (computed) return null;
    return propertyName(tree, key, computed);
}

fn propertyName(tree: *const ast.Tree, key: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (computed) return null;
    return switch (tree.data(key)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
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
