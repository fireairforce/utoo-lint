const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-unsafe-declaration-merging";

const DeclKind = enum {
    class,
    interface,
};

const DeclKindMap = std.AutoHashMap(ast.NodeIndex, DeclKind);

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var decl_kinds = DeclKindMap.init(allocator);
    defer decl_kinds.deinit();

    var visitor = DeclKindVisitor{ .decl_kinds = &decl_kinds };
    try traverser.basic.traverse(DeclKindVisitor, tree, &visitor);

    var iter = symbol_table.iterSymbols();
    while (iter.next()) |entry| {
        const decls = symbol_table.symbolDecls(entry.id);
        if (decls.len <= 1) continue;

        var has_class = false;
        var has_interface = false;
        for (decls) |decl| {
            switch (decl_kinds.get(decl) orelse continue) {
                .class => has_class = true,
                .interface => has_interface = true,
            }
        }
        if (!has_class or !has_interface) continue;

        const name = tree.string(entry.symbol.name);
        for (decls) |decl| {
            if (decl_kinds.get(decl) == null) continue;
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .@"error",
                id,
                tree.span(decl),
                "Unsafe declaration merging between class and interface `{s}`.",
                .{name},
            );
        }
    }
}

const DeclKindVisitor = struct {
    decl_kinds: *DeclKindMap,

    pub fn enter_class(
        self: *DeclKindVisitor,
        class: ast.Class,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (class.id != .null) {
            try self.decl_kinds.put(class.id, .class);
        }
        return .proceed;
    }

    pub fn enter_ts_interface_declaration(
        self: *DeclKindVisitor,
        declaration: ast.TSInterfaceDeclaration,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.decl_kinds.put(declaration.id, .interface);
        return .proceed;
    }
};
