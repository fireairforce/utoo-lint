const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "prefer-object-spread";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (isPreferableObjectAssign(ctx.tree, self.symbol_table, call)) {
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                "Use an object spread instead of Object.assign.",
                ctx.tree.span(index),
            );
        }

        return .proceed;
    }
};

fn isPreferableObjectAssign(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    call: ast.CallExpression,
) bool {
    const arguments = tree.extra(call.arguments);
    if (arguments.len < 2) return false;
    if (!isObjectExpression(tree, arguments[0])) return false;
    for (arguments[1..]) |argument| {
        if (tree.data(argument) == .spread_element) return false;
    }
    return isGlobalObjectAssign(tree, symbol_table, call.callee);
}

fn isObjectExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .object_expression => true,
        else => false,
    };
}

fn isGlobalObjectAssign(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) bool {
    const unwrapped = unwrapTransparent(tree, index);
    const member = switch (tree.data(unwrapped)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.optional) return false;
    const property_name = memberPropertyName(tree, member) orelse return false;
    if (!std.mem.eql(u8, property_name, "assign")) return false;
    const object = unwrapTransparent(tree, member.object);
    if (!isIdentifierReference(tree, object, "Object")) return false;
    return isUnresolvedReference(symbol_table, object);
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

fn memberPropertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;

    if (!member.computed) {
        return switch (tree.data(member.property)) {
            .identifier_name => |identifier| tree.string(identifier.name),
            else => null,
        };
    }

    return switch (tree.data(unwrapTransparent(tree, member.property))) {
        .string_literal => |literal| tree.string(literal.value),
        .template_literal => |literal| templateStringValue(tree, literal),
        else => null,
    };
}

fn templateStringValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;
    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return "";
    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
}

fn isIdentifierReference(tree: *const ast.Tree, index: ast.NodeIndex, expected: []const u8) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), expected),
        else => false,
    };
}

fn isUnresolvedReference(
    symbol_table: traverser.semantic.SymbolTable,
    node: ast.NodeIndex,
) bool {
    var iter = symbol_table.iterReferences();
    while (iter.next()) |entry| {
        if (entry.reference.node == node) {
            return symbol_table.referenceSymbol(entry.id) == .none;
        }
    }

    return false;
}
