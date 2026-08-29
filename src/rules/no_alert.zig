const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-alert";

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
        if (forbiddenCallee(ctx.tree, self.symbol_table, call.callee)) |name| {
            try core.addDiagnosticFmt(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                ctx.tree.span(index),
                "Unexpected {s}.",
                .{name},
            );
        }

        return .proceed;
    }
};

fn forbiddenCallee(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    callee: ast.NodeIndex,
) ?[]const u8 {
    const unwrapped = unwrapTransparent(tree, callee);

    if (identifierReferenceName(tree, unwrapped)) |name| {
        if (isForbiddenFunction(name) and isUnresolvedReference(symbol_table, unwrapped)) {
            return name;
        }
        return null;
    }

    const member = switch (tree.data(unwrapped)) {
        .member_expression => |member| member,
        else => return null,
    };

    const object = unwrapTransparent(tree, member.object);
    const object_name = identifierReferenceName(tree, object) orelse return null;
    if (!isGlobalObject(object_name) or !isUnresolvedReference(symbol_table, object)) {
        return null;
    }

    const property_name = propertyName(tree, member) orelse return null;
    if (isForbiddenFunction(property_name)) return property_name;

    return null;
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
            else => null,
        }
    else switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isUnresolvedReference(
    symbol_table: traverser.semantic.SymbolTable,
    node: ast.NodeIndex,
) bool {
    return symbol_table.isUnresolvedReference(node);
}

fn isForbiddenFunction(name: []const u8) bool {
    return std.mem.eql(u8, name, "alert") or
        std.mem.eql(u8, name, "confirm") or
        std.mem.eql(u8, name, "prompt");
}

fn isGlobalObject(name: []const u8) bool {
    return std.mem.eql(u8, name, "window") or
        std.mem.eql(u8, name, "globalThis");
}
