const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-useless-catch";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    clause: ast.CatchClause,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (clause.param == .null) return;

    const parameter_name = bindingName(tree, clause.param) orelse return;
    const body = switch (tree.data(clause.body)) {
        .block_statement => |body| body,
        else => return,
    };
    if (body.body.len != 1) return;

    const statement_index = tree.extra(body.body)[0];
    const thrown = switch (tree.data(statement_index)) {
        .throw_statement => |statement| statement.argument,
        else => return,
    };

    if (!isIdentifierReference(tree, thrown, parameter_name)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unnecessary catch clause.",
        tree.span(index),
    );
}

fn bindingName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isIdentifierReference(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        .chain_expression => |chain| isIdentifierReference(tree, chain.expression, name),
        .parenthesized_expression => |parenthesized| isIdentifierReference(tree, parenthesized.expression, name),
        else => false,
    };
}
