const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "react/no-is-mounted";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    const callee = unwrapTransparent(tree, call.callee);
    if (!isThisIsMountedCall(tree, callee)) return;
    if (!hasMethodLikeAncestor(tree, ctx)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Do not use isMounted",
        tree.span(callee),
    );
}

fn isThisIsMountedCall(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const member = switch (tree.data(index)) {
        .member_expression => |member| member,
        else => return false,
    };

    if (member.computed) return false;
    if (tree.data(unwrapTransparent(tree, member.object)) != .this_expression) return false;

    const property = switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => return false,
    };
    return std.mem.eql(u8, property, "isMounted");
}

fn hasMethodLikeAncestor(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .object_property,
            .method_definition,
            => return true,
            else => {},
        }
    }
    return false;
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
