const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-import-assign";

const ReferenceLookup = std.AutoHashMap(ast.NodeIndex, traverser.semantic.SymbolId);

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var reference_lookup = try buildReferenceLookup(allocator, symbol_table);
    defer reference_lookup.deinit();

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
        .reference_lookup = &reference_lookup,
    };
    defer visitor.namespace_import_names.deinit(allocator);

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,
    reference_lookup: *const ReferenceLookup,
    namespace_import_names: std.StringHashMapUnmanaged(void) = .empty,

    pub fn enter_import_namespace_specifier(
        self: *Visitor,
        specifier: ast.ImportNamespaceSpecifier,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const name = bindingIdentifierName(ctx.tree, specifier.local) orelse return .proceed;
        try self.namespace_import_names.put(self.allocator, name, {});
        return .proceed;
    }

    pub fn enter_assignment_expression(
        self: *Visitor,
        expression: ast.AssignmentExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.isForbiddenTarget(ctx.tree, expression.left) or self.isForbiddenNamespaceMember(ctx.tree, expression.left)) {
            try self.addDiagnostic(ctx.tree, index);
        }
        return .proceed;
    }

    pub fn enter_update_expression(
        self: *Visitor,
        expression: ast.UpdateExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (self.isForbiddenTarget(ctx.tree, expression.argument) or self.isForbiddenNamespaceMember(ctx.tree, expression.argument)) {
            try self.addDiagnostic(ctx.tree, index);
        }
        return .proceed;
    }

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (isObjectAssignCall(ctx.tree, self.reference_lookup, call.callee) and call.arguments.len > 0) {
            const first = ctx.tree.extra(call.arguments)[0];
            if (self.namespaceSymbolFromExpression(ctx.tree, first) != .none) {
                try self.addDiagnostic(ctx.tree, index);
            }
        }
        return .proceed;
    }

    fn isForbiddenTarget(self: *Visitor, tree: *const ast.Tree, target: ast.NodeIndex) bool {
        const symbol_id = self.symbolFromIdentifierExpression(tree, target);
        if (symbol_id == .none) return false;

        const symbol = self.symbol_table.getSymbol(symbol_id);
        return symbol.flags.import;
    }

    fn isForbiddenNamespaceMember(self: *Visitor, tree: *const ast.Tree, target: ast.NodeIndex) bool {
        const member = switch (tree.data(unwrapTransparent(tree, target))) {
            .member_expression => |member| member,
            else => return false,
        };

        return self.namespaceSymbolFromExpression(tree, member.object) != .none;
    }

    fn namespaceSymbolFromExpression(self: *Visitor, tree: *const ast.Tree, expression: ast.NodeIndex) traverser.semantic.SymbolId {
        const symbol_id = self.symbolFromIdentifierExpression(tree, expression);
        if (symbol_id == .none) return .none;

        const symbol = self.symbol_table.getSymbol(symbol_id);
        if (!symbol.flags.import) return .none;

        const name = tree.string(symbol.name);
        if (!self.namespace_import_names.contains(name)) return .none;

        return symbol_id;
    }

    fn symbolFromIdentifierExpression(self: *Visitor, tree: *const ast.Tree, expression: ast.NodeIndex) traverser.semantic.SymbolId {
        const identifier = unwrapTransparent(tree, expression);
        if (!isIdentifierReference(tree, identifier)) return .none;
        return self.reference_lookup.get(identifier) orelse .none;
    }

    fn addDiagnostic(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            "Imported bindings are read-only.",
            tree.span(index),
        );
    }
};

fn buildReferenceLookup(
    allocator: Allocator,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!ReferenceLookup {
    var lookup = ReferenceLookup.init(allocator);
    errdefer lookup.deinit();
    try lookup.ensureTotalCapacity(@intCast(symbol_table.references.len));

    var iter = symbol_table.iterReferences();
    while (iter.next()) |entry| {
        try lookup.put(entry.reference.node, symbol_table.referenceSymbol(entry.id));
    }

    return lookup;
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

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isIdentifierReference(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .identifier_reference => true,
        else => false,
    };
}

fn isObjectAssignCall(
    tree: *const ast.Tree,
    reference_lookup: *const ReferenceLookup,
    callee: ast.NodeIndex,
) bool {
    const member = switch (tree.data(unwrapTransparent(tree, callee))) {
        .member_expression => |member| member,
        else => return false,
    };

    const property_name = propertyName(tree, member) orelse return false;
    if (!std.mem.eql(u8, property_name, "assign")) return false;

    const object = unwrapTransparent(tree, member.object);
    const object_name = identifierReferenceName(tree, object) orelse return false;
    return std.mem.eql(u8, object_name, "Object") and isUnresolvedReference(reference_lookup, object);
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
    reference_lookup: *const ReferenceLookup,
    node: ast.NodeIndex,
) bool {
    return (reference_lookup.get(node) orelse return false) == .none;
}
