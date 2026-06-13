const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/ant/no-deprecated-variable";

pub fn checkMemberExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isDeprecatedIdentifier(tree, member.object) and !isDeprecatedIdentifier(tree, member.property)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "ap 不推荐使用。强烈建议 使用 my 替代。",
        tree.span(index),
    );
}

fn isDeprecatedIdentifier(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const name = switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        else => return false,
    };
    return std.mem.eql(u8, name, "ap") or std.mem.eql(u8, name, "AlipayJSBridge");
}
