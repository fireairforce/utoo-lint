const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "react/jsx-no-undef";

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

    pub fn enter_jsx_opening_element(
        self: *Visitor,
        opening: ast.JSXOpeningElement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const name_node = jsxReferenceNameNode(ctx.tree, opening.name) orelse return .proceed;
        const name = jsxIdentifierName(ctx.tree, name_node) orelse return .proceed;

        if (std.mem.eql(u8, name, "this")) return .proceed;
        if (!isUnresolvedReference(self.symbol_table, name_node)) return .proceed;

        try core.addDiagnosticFmt(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            ctx.tree.span(name_node),
            "'{s}' is not defined.",
            .{name},
        );

        return .proceed;
    }
};

fn jsxReferenceNameNode(tree: *const ast.Tree, name_index: ast.NodeIndex) ?ast.NodeIndex {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| if (isDOMComponentName(tree.string(identifier.name))) null else name_index,
        .jsx_member_expression => |member| jsxMemberRootNameNode(tree, member.object),
        .jsx_namespaced_name => null,
        else => null,
    };
}

fn jsxMemberRootNameNode(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.NodeIndex {
    var current = index;
    while (current != .null) {
        switch (tree.data(current)) {
            .jsx_identifier => return current,
            .jsx_member_expression => |member| current = member.object,
            else => return null,
        }
    }
    return null;
}

fn jsxIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isDOMComponentName(name: []const u8) bool {
    return name.len > 0 and name[0] >= 'a' and name[0] <= 'z';
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
