const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/ant/prefer-catch-unsafe-func-call";

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    const message = unsafeCallMessage(tree, call) orelse return;
    if (isInsideTryBlock(tree, ctx)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        message,
        tree.span(index),
    );
}

fn unsafeCallMessage(tree: *const ast.Tree, call: ast.CallExpression) ?[]const u8 {
    const callee = unwrapTransparent(tree, call.callee);
    if (identifierName(tree, callee)) |name| {
        if (std.mem.eql(u8, name, "decodeURIComponent")) {
            return "`decodeURIComponent`存在无法解析出错可能, 需进行catch处理";
        }
        return null;
    }

    const member = switch (tree.data(callee)) {
        .member_expression => |member| member,
        else => return null,
    };
    const object_name = identifierName(tree, unwrapTransparent(tree, member.object)) orelse return null;
    const property_name = identifierName(tree, unwrapTransparent(tree, member.property)) orelse return null;
    if (std.mem.eql(u8, object_name, "localStorage") and std.mem.eql(u8, property_name, "setItem")) {
        return "`localStorage.setItem`存在无法写入报错可能, 需进行catch处理";
    }
    return null;
}

fn isInsideTryBlock(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        if (tree.data(ancestor) != .block_statement) continue;
        const parent = ctx.path.ancestor(depth + 1) orelse continue;
        const try_statement = switch (tree.data(parent)) {
            .try_statement => |statement| statement,
            else => continue,
        };
        if (try_statement.block == ancestor) return true;
    }
    return false;
}

fn identifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
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
