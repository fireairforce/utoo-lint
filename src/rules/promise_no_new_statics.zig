const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "promise/no-new-statics";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NewExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const member = switch (tree.data(unwrapTransparent(tree, expression.callee))) {
        .member_expression => |member| member,
        else => return,
    };
    if (!isIdentifierReferenceNamed(tree, member.object, "Promise")) return;

    const name = memberPropertyName(tree, member) orelse return;
    if (!isPromiseStatic(name)) return;

    const expression_span = tree.span(index);
    const fix_end = @min(expression_span.start + 4, expression_span.end);
    const message = try std.fmt.allocPrint(allocator, "Avoid calling 'new' on 'Promise.{s}()'", .{name});
    defer allocator.free(message);
    try core.addDiagnosticWithFix(
        allocator,
        diagnostics,
        .warning,
        id,
        message,
        expression_span,
        .{
            .span = .{ .start = expression_span.start, .end = fix_end },
            .replacement = "",
        },
    );
}

fn isPromiseStatic(name: []const u8) bool {
    const statics = [_][]const u8{
        "all",
        "allSettled",
        "any",
        "race",
        "reject",
        "resolve",
        "withResolvers",
    };
    for (statics) |static_name| {
        if (std.mem.eql(u8, name, static_name)) return true;
    }
    return false;
}

fn memberPropertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;
    return switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
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
