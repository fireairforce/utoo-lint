const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-restricted-globals";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    restrictions: core.NoRestrictedGlobals,
) Allocator.Error!void {
    if (restrictions.count == 0) return;

    var iter = symbol_table.iterUnresolved();
    while (iter.next()) |entry| {
        const reference = entry.reference;
        if (reference.kind != .value) continue;

        const name = tree.string(reference.name);
        const restriction = restrictions.find(name) orelse continue;
        try addDiagnostic(allocator, diagnostics, tree, reference.node, restriction, name);
    }

    if (!restrictions.check_global_object) return;

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
        .restrictions = restrictions,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,
    restrictions: core.NoRestrictedGlobals,

    pub fn enter_member_expression(
        self: *Visitor,
        member: ast.MemberExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const property = propertyName(ctx.tree, member) orelse return .proceed;
        const restriction = self.restrictions.find(property) orelse return .proceed;

        if (!isGlobalObjectAccess(ctx.tree, self.symbol_table, member.object, self.restrictions)) {
            return .proceed;
        }

        try addDiagnostic(self.allocator, self.diagnostics, ctx.tree, index, restriction, property);
        return .proceed;
    }
};

fn isGlobalObjectAccess(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
    restrictions: core.NoRestrictedGlobals,
) bool {
    const object = unwrapTransparent(tree, index);
    if (identifierReferenceName(tree, object)) |name| {
        return isConfiguredGlobalObject(restrictions, name) and isUnresolvedReference(symbol_table, object);
    }

    const member = switch (tree.data(object)) {
        .member_expression => |member| member,
        else => return false,
    };

    const property = propertyName(tree, member) orelse return false;
    const root = globalObjectRoot(tree, member.object) orelse return false;
    if (!std.mem.eql(u8, property, root)) return false;

    return isConfiguredGlobalObject(restrictions, root) and isUnresolvedRootReference(tree, symbol_table, member.object, root);
}

fn globalObjectRoot(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    const unwrapped = unwrapTransparent(tree, index);
    if (identifierReferenceName(tree, unwrapped)) |name| return name;

    const member = switch (tree.data(unwrapped)) {
        .member_expression => |member| member,
        else => return null,
    };
    const property = propertyName(tree, member) orelse return null;
    const root = globalObjectRoot(tree, member.object) orelse return null;
    if (!std.mem.eql(u8, property, root)) return null;
    return root;
}

fn isUnresolvedRootReference(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
    root: []const u8,
) bool {
    const unwrapped = unwrapTransparent(tree, index);
    if (identifierReferenceName(tree, unwrapped)) |name| {
        return std.mem.eql(u8, name, root) and isUnresolvedReference(symbol_table, unwrapped);
    }

    const member = switch (tree.data(unwrapped)) {
        .member_expression => |member| member,
        else => return false,
    };
    const property = propertyName(tree, member) orelse return false;
    if (!std.mem.eql(u8, property, root)) return false;
    return isUnresolvedRootReference(tree, symbol_table, member.object, root);
}

fn isConfiguredGlobalObject(restrictions: core.NoRestrictedGlobals, name: []const u8) bool {
    return isDefaultGlobalObject(name) or restrictions.global_objects.contains(name);
}

fn isDefaultGlobalObject(name: []const u8) bool {
    return std.mem.eql(u8, name, "globalThis") or
        std.mem.eql(u8, name, "self") or
        std.mem.eql(u8, name, "window");
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
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
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

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
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

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    restriction: *const core.NoRestrictedGlobalEntry,
    name: []const u8,
) Allocator.Error!void {
    if (restriction.message()) |message| {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "Unexpected use of '{s}'. {s}",
            .{ name, message },
        );
    } else {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "Unexpected use of '{s}'.",
            .{name},
        );
    }
}
