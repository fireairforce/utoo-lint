const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "promise/no-return-wrap";

pub const Options = struct {
    allow_reject: bool = false,
};

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    const kind = promiseWrapperKind(tree, call) orelse return;
    if (kind == .reject and options.allow_reject) return;

    const parent = nextNonTransparentAncestor(tree, ctx, 1) orelse return;
    const report_index = switch (tree.data(parent.index)) {
        .return_statement => parent.index,
        .arrow_function_expression => |arrow| if (arrow.expression and unwrapTransparent(tree, arrow.body) == index) index else return,
        else => return,
    };
    if (!isInPromiseHandler(tree, ctx)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        switch (kind) {
            .resolve => "Avoid wrapping return values in Promise.resolve",
            .reject => "Expected throw instead of Promise.reject",
        },
        tree.span(report_index),
    );
}

const WrapperKind = enum { resolve, reject };

fn promiseWrapperKind(tree: *const ast.Tree, call: ast.CallExpression) ?WrapperKind {
    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return null,
    };
    if (!identifierReferenceNamed(tree, member.object, "Promise")) return null;
    const property = memberPropertyName(tree, member) orelse return null;
    if (std.mem.eql(u8, property, "resolve")) return .resolve;
    if (std.mem.eql(u8, property, "reject")) return .reject;
    return null;
}

fn isInPromiseHandler(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    var function_depth: usize = 1;
    var candidate = while (ctx.path.ancestor(function_depth)) |ancestor| : (function_depth += 1) {
        switch (tree.data(ancestor)) {
            .function => |function| if (function.type == .function_expression) break ancestor,
            .arrow_function_expression => break ancestor,
            else => {},
        }
    } else return false;

    var candidate_depth = function_depth;
    while (true) {
        const member_ancestor = nextNonTransparentAncestor(tree, ctx, candidate_depth + 1) orelse break;
        const member = switch (tree.data(member_ancestor.index)) {
            .member_expression => |member| member,
            else => break,
        };
        if (unwrapTransparent(tree, member.object) != unwrapTransparent(tree, candidate)) break;
        const property = memberPropertyName(tree, member) orelse break;
        if (!std.mem.eql(u8, property, "bind")) break;

        const call_ancestor = nextNonTransparentAncestor(tree, ctx, member_ancestor.depth + 1) orelse break;
        const bind_call = switch (tree.data(call_ancestor.index)) {
            .call_expression => |call| call,
            else => break,
        };
        if (unwrapTransparent(tree, bind_call.callee) != member_ancestor.index) break;
        candidate = call_ancestor.index;
        candidate_depth = call_ancestor.depth;
    }

    const parent = nextNonTransparentAncestor(tree, ctx, candidate_depth + 1) orelse return false;
    const promise_call = switch (tree.data(parent.index)) {
        .call_expression => |call| call,
        else => return false,
    };
    return isPromiseCall(tree, promise_call);
}

const PathNode = struct {
    index: ast.NodeIndex,
    depth: usize,
};

fn nextNonTransparentAncestor(
    tree: *const ast.Tree,
    ctx: *traverser.basic.Ctx,
    start_depth: usize,
) ?PathNode {
    var depth = start_depth;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .chain_expression, .parenthesized_expression => continue,
            else => return .{ .index = ancestor, .depth = depth },
        }
    }
    return null;
}

fn isPromiseCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return false,
    };
    const property = memberPropertyName(tree, member) orelse return false;
    if (std.mem.eql(u8, property, "then") or
        std.mem.eql(u8, property, "catch") or
        std.mem.eql(u8, property, "finally")) return true;

    const object = unwrapTransparent(tree, member.object);
    if (tree.data(object) == .call_expression) {
        return isPromiseCall(tree, tree.data(object).call_expression);
    }
    if (!identifierReferenceNamed(tree, object, "Promise")) return false;
    return std.mem.eql(u8, property, "all") or
        std.mem.eql(u8, property, "allSettled") or
        std.mem.eql(u8, property, "any") or
        std.mem.eql(u8, property, "race") or
        std.mem.eql(u8, property, "reject") or
        std.mem.eql(u8, property, "resolve");
}

fn identifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
    };
}

fn memberPropertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    return switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
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
