const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/spmLint/use-labeled-spm";

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const callee = switch (tree.data(call.callee)) {
        .member_expression => |member| member,
        else => return,
    };

    if (!isTrackedFnName(memberPropertyName(tree, callee) orelse return)) return;
    if (!isTracertReceiver(tree, callee.object)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "请优先使用声明式埋点",
        tree.span(index),
    );
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
    return identifierReferenceName(tree, member.property);
}

fn isTracertIdentifier(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const name = identifierReferenceName(tree, index) orelse return false;
    return std.mem.eql(u8, name, "tracert") or
        std.mem.eql(u8, name, "Tracert") or
        std.mem.eql(u8, name, "$tracert");
}

fn isTrackedFnName(name: []const u8) bool {
    return std.mem.eql(u8, name, "expo") or
        std.mem.eql(u8, name, "logPv") or
        std.mem.eql(u8, name, "click");
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}
