const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-eval";

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
        if (isEvalCall(ctx.tree, self.symbol_table, call.callee)) {
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                "eval can be harmful.",
                ctx.tree.span(index),
            );
        }

        return .proceed;
    }
};

fn isEvalCall(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    callee: ast.NodeIndex,
) bool {
    const unwrapped = unwrapTransparent(tree, callee);

    if (identifierReferenceName(tree, unwrapped)) |name| {
        return std.mem.eql(u8, name, "eval");
    }

    switch (tree.data(unwrapped)) {
        .sequence_expression => |sequence| {
            const expressions = tree.extra(sequence.expressions);
            if (expressions.len == 0) return false;
            const last = unwrapTransparent(tree, expressions[expressions.len - 1]);
            const name = identifierReferenceName(tree, last) orelse return false;
            return std.mem.eql(u8, name, "eval");
        },
        .member_expression => |member| return isGlobalEvalMember(tree, symbol_table, member),
        else => return false,
    }
}

fn isGlobalEvalMember(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    member: ast.MemberExpression,
) bool {
    const property_name = propertyName(tree, member) orelse return false;
    if (!std.mem.eql(u8, property_name, "eval")) return false;

    const object = unwrapTransparent(tree, member.object);
    const object_name = identifierReferenceName(tree, object) orelse return false;
    return isGlobalObjectName(object_name) and isUnresolvedReference(symbol_table, object);
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

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn propertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;

    return if (member.computed)
        switch (tree.data(member.property)) {
            .string_literal => |literal| tree.string(literal.value),
            .template_literal => |literal| templateStringValue(tree, literal),
            else => null,
        }
    else switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
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

fn isGlobalObjectName(name: []const u8) bool {
    return std.mem.eql(u8, name, "window") or
        std.mem.eql(u8, name, "globalThis") or
        std.mem.eql(u8, name, "global");
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
