const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/spmLint/valid-manual-pv";

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
) Allocator.Error!void {
    if (!isTracertCallNamed(tree, call, "logPv")) return;

    const args = tree.extra(call.arguments);
    if (args.len == 0) return;
    if (passesObjectParam(tree, args[0])) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "函数 logPv 第一个参数类型为 Object",
        tree.span(args[0]),
    );
}

fn isTracertCallNamed(tree: *const ast.Tree, call: ast.CallExpression, name: []const u8) bool {
    const callee = switch (tree.data(call.callee)) {
        .member_expression => |member| member,
        else => return false,
    };

    const property = memberPropertyName(tree, callee) orelse return false;
    return std.mem.eql(u8, property, name) and isTracertReceiver(tree, callee.object);
}

fn passesObjectParam(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .object_expression,
        .call_expression,
        .conditional_expression,
        => true,
        .identifier_reference => |identifier| !std.mem.eql(u8, tree.string(identifier.name), "undefined"),
        .member_expression => |member| !member.computed and memberPropertyName(tree, member) != null,
        else => false,
    };
}

fn isTracertReceiver(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (isTracertIdentifier(tree, index)) return true;

    const member = switch (tree.data(index)) {
        .member_expression => |member| member,
        else => return false,
    };
    return !member.computed and isTracertIdentifier(tree, member.property);
}

fn memberPropertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.computed) return null;
    return identifierName(tree, member.property);
}

fn isTracertIdentifier(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const name = identifierName(tree, index) orelse return false;
    return std.mem.eql(u8, name, "tracert") or
        std.mem.eql(u8, name, "Tracert") or
        std.mem.eql(u8, name, "$tracert");
}

fn identifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}
