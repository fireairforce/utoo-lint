const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "promise/valid-params";

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    exclude: core.PromiseValidParamsExclusions,
) Allocator.Error!void {
    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return,
    };
    const name = memberPropertyName(tree, member) orelse return;
    if (!isPromiseCall(tree, call) or exclude.contains(name)) return;

    const count = call.arguments.len;
    if (std.mem.eql(u8, name, "resolve") or std.mem.eql(u8, name, "reject")) {
        if (count <= 1) return;
        return addDiagnostic(allocator, diagnostics, tree, call, name, count, "0 or 1 arguments");
    }
    if (std.mem.eql(u8, name, "then")) {
        if (count >= 1 and count <= 2) return;
        return addDiagnostic(allocator, diagnostics, tree, call, name, count, "1 or 2 arguments");
    }
    if (std.mem.eql(u8, name, "race") or
        std.mem.eql(u8, name, "all") or
        std.mem.eql(u8, name, "allSettled") or
        std.mem.eql(u8, name, "any") or
        std.mem.eql(u8, name, "catch") or
        std.mem.eql(u8, name, "finally"))
    {
        if (count == 1) return;
        return addDiagnostic(allocator, diagnostics, tree, call, name, count, "1 argument");
    }
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    name: []const u8,
    count: usize,
    requirement: []const u8,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(call.callee),
        "Promise.{s}() requires {s}, but received {d}",
        .{ name, requirement, count },
    );
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
