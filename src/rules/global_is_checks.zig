const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const no_global_is_finite = @import("no_global_is_finite.zig");
const no_global_is_nan = @import("no_global_is_nan.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    check_is_finite: bool,
    check_is_nan: bool,
) Allocator.Error!void {
    if (!check_is_finite and !check_is_nan) return;

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
        .check_is_finite = check_is_finite,
        .check_is_nan = check_is_nan,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,
    check_is_finite: bool,
    check_is_nan: bool,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const kind = globalIsCall(ctx.tree, self.symbol_table, call.callee) orelse return .proceed;

        switch (kind) {
            .is_finite => {
                if (self.check_is_finite) {
                    try core.addDiagnostic(
                        self.allocator,
                        self.diagnostics,
                        .warning,
                        no_global_is_finite.id,
                        "isFinite is unsafe. It attempts a type coercion. Use Number.isFinite instead.",
                        ctx.tree.span(index),
                    );
                }
            },
            .is_nan => {
                if (self.check_is_nan) {
                    try core.addDiagnostic(
                        self.allocator,
                        self.diagnostics,
                        .warning,
                        no_global_is_nan.id,
                        "isNaN is unsafe. It attempts a type coercion. Use Number.isNaN instead.",
                        ctx.tree.span(index),
                    );
                }
            },
        }

        return .proceed;
    }
};

const GlobalIsKind = enum {
    is_finite,
    is_nan,
};

fn globalIsCall(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    callee: ast.NodeIndex,
) ?GlobalIsKind {
    const unwrapped = unwrapTransparent(tree, callee);

    if (identifierReferenceName(tree, unwrapped)) |name| {
        if (globalIsKind(name)) |kind| {
            return if (isUnresolvedReference(symbol_table, unwrapped)) kind else null;
        }
        return null;
    }

    const member = switch (tree.data(unwrapped)) {
        .member_expression => |member| member,
        else => return null,
    };

    const property_name = propertyName(tree, member) orelse return null;
    const kind = globalIsKind(property_name) orelse return null;

    const object = unwrapTransparent(tree, member.object);
    const object_name = identifierReferenceName(tree, object) orelse return null;
    if (!std.mem.eql(u8, object_name, "globalThis")) return null;

    return if (isUnresolvedReference(symbol_table, object)) kind else null;
}

fn globalIsKind(name: []const u8) ?GlobalIsKind {
    if (std.mem.eql(u8, name, "isFinite")) return .is_finite;
    if (std.mem.eql(u8, name, "isNaN")) return .is_nan;
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
    var iter = symbol_table.iterReferences();
    while (iter.next()) |entry| {
        if (entry.reference.node == node) {
            return symbol_table.referenceSymbol(entry.id) == .none;
        }
    }

    return false;
}
