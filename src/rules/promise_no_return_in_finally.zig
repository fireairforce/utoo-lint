const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "promise/no-return-in-finally";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
) Allocator.Error!void {
    const member = switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .member_expression => |member| member,
        else => return,
    };
    const property = memberPropertyName(tree, member) orelse return;
    if (!std.mem.eql(u8, property, "finally")) return;

    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0 or !callbackHasTopLevelReturn(tree, arguments[0])) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "No return in finally",
        tree.span(member.property),
    );
}

fn callbackHasTopLevelReturn(tree: *const ast.Tree, callback_index: ast.NodeIndex) bool {
    const body_index = switch (tree.data(unwrapTransparent(tree, callback_index))) {
        .function => |function| function.body,
        .arrow_function_expression => |arrow| if (arrow.expression) return false else arrow.body,
        else => return false,
    };
    const statements = switch (tree.data(body_index)) {
        .function_body => |body| body.body,
        .block_statement => |block| block.body,
        else => return false,
    };
    for (tree.extra(statements)) |statement| {
        if (tree.data(statement) == .return_statement) return true;
    }
    return false;
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
