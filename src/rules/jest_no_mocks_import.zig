const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "jest/no-mocks-import";

const message = "Mocks should not be manually imported from a __mocks__ directory. Instead use `jest.mock` and import from the original module path";

pub fn checkImportDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.ImportDeclaration,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkSource(allocator, diagnostics, tree, declaration.source, tree.span(index));
}

pub fn checkImportExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ImportExpression,
) Allocator.Error!void {
    try checkSource(allocator, diagnostics, tree, expression.source, tree.span(expression.source));
}

pub fn checkCallExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
) Allocator.Error!void {
    if (!isRequireIdentifier(tree, call.callee)) return;
    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0) return;
    try checkSource(allocator, diagnostics, tree, arguments[0], tree.span(arguments[0]));
}

fn checkSource(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    source_index: ast.NodeIndex,
    diagnostic_span: ast.Span,
) Allocator.Error!void {
    const source = staticStringValue(tree, source_index) orelse return;
    if (!isMockPath(source)) return;
    try core.addDiagnostic(allocator, diagnostics, .warning, id, message, diagnostic_span);
}

fn isMockPath(path: []const u8) bool {
    var segments = std.mem.splitScalar(u8, path, '/');
    while (segments.next()) |segment| {
        if (std.mem.eql(u8, segment, "__mocks__")) return true;
    }
    return false;
}

fn isRequireIdentifier(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), "require"),
        else => false,
    };
}

fn staticStringValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .string_literal => |literal| tree.string(literal.value),
        .template_literal => |literal| templateStringValue(tree, literal),
        else => null,
    };
}

fn templateStringValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;
    const quasis = tree.extra(literal.quasis);
    if (quasis.len != 1) return null;
    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;
    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |expression| current = expression.expression,
            .parenthesized_expression => |expression| current = expression.expression,
            .ts_as_expression => |expression| current = expression.expression,
            .ts_satisfies_expression => |expression| current = expression.expression,
            .ts_non_null_expression => |expression| current = expression.expression,
            .ts_type_assertion => |expression| current = expression.expression,
            else => return current,
        }
    }
    return current;
}
