const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "react/no-render-return-value";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    const callee = unwrapTransparent(tree, call.callee);
    if (!isReactDomRenderCallee(tree, callee)) return;
    if (!usesReturnValue(tree, ctx)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Do not depend on the return value from ReactDOM.render",
        tree.span(callee),
    );
}

fn isReactDomRenderCallee(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const member = switch (tree.data(index)) {
        .member_expression => |member| member,
        else => return false,
    };

    if (member.computed) return false;
    if (!isIdentifierReferenceNamed(tree, unwrapTransparent(tree, member.object), "ReactDOM")) return false;

    const property = switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => return false,
    };
    return std.mem.eql(u8, property, "render");
}

fn usesReturnValue(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .parenthesized_expression => continue,
            .variable_declarator,
            .object_property,
            .return_statement,
            .arrow_function_expression,
            .assignment_expression,
            => return true,
            else => return false,
        }
    }
    return false;
}

fn isIdentifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    return switch (tree.data(index)) {
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
