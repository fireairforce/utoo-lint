const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "react/no-forward-ref";

const message = "In React 19, pass ref as a prop instead of using forwardRef";
const ReferenceLookup = std.AutoHashMap(ast.NodeIndex, traverser.semantic.SymbolId);

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var direct_imports: std.StringHashMapUnmanaged(void) = .empty;
    defer direct_imports.deinit(allocator);
    var namespace_imports: std.StringHashMapUnmanaged(void) = .empty;
    defer namespace_imports.deinit(allocator);
    try collectReactImports(allocator, tree, &direct_imports, &namespace_imports);
    if (direct_imports.count() == 0 and namespace_imports.count() == 0) return;

    var reference_lookup = try buildReferenceLookup(allocator, symbol_table);
    defer reference_lookup.deinit();

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
        .reference_lookup = &reference_lookup,
        .direct_imports = &direct_imports,
        .namespace_imports = &namespace_imports,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,
    reference_lookup: *const ReferenceLookup,
    direct_imports: *const std.StringHashMapUnmanaged(void),
    namespace_imports: *const std.StringHashMapUnmanaged(void),

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const callee = unwrapTransparent(ctx.tree, call.callee);
        if (!self.isForwardRefCallee(ctx.tree, callee)) return .proceed;

        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            message,
            ctx.tree.span(callee),
        );
        return .proceed;
    }

    fn isForwardRefCallee(self: *const Visitor, tree: *const ast.Tree, index: ast.NodeIndex) bool {
        if (tree.data(index) == .identifier_reference) {
            return self.isImportedReference(tree, index, self.direct_imports);
        }

        const member = switch (tree.data(index)) {
            .member_expression => |member| member,
            else => return false,
        };
        const property = memberPropertyName(tree, member) orelse return false;
        if (!std.mem.eql(u8, property, "forwardRef")) return false;

        const object = unwrapTransparent(tree, member.object);
        if (tree.data(object) != .identifier_reference) return false;
        return self.isImportedReference(tree, object, self.namespace_imports);
    }

    fn isImportedReference(
        self: *const Visitor,
        tree: *const ast.Tree,
        reference: ast.NodeIndex,
        imported_names: *const std.StringHashMapUnmanaged(void),
    ) bool {
        const symbol_id = self.reference_lookup.get(reference) orelse return false;
        if (symbol_id == .none) return false;
        const symbol = self.symbol_table.getSymbol(symbol_id);
        if (!symbol.flags.import) return false;
        return imported_names.contains(tree.string(symbol.name));
    }
};

fn collectReactImports(
    allocator: Allocator,
    tree: *const ast.Tree,
    direct_imports: *std.StringHashMapUnmanaged(void),
    namespace_imports: *std.StringHashMapUnmanaged(void),
) Allocator.Error!void {
    const program = switch (tree.data(tree.root)) {
        .program => |program| program,
        else => return,
    };

    for (tree.extra(program.body)) |statement_index| {
        const declaration = switch (tree.data(statement_index)) {
            .import_declaration => |declaration| declaration,
            else => continue,
        };
        if (declaration.import_kind == .type) continue;
        const source = stringLiteralValue(tree, declaration.source) orelse continue;
        if (!std.mem.eql(u8, source, "react")) continue;

        for (tree.extra(declaration.specifiers)) |specifier_index| {
            switch (tree.data(specifier_index)) {
                .import_specifier => |specifier| {
                    if (specifier.import_kind == .type) continue;
                    const imported = propertyName(tree, specifier.imported) orelse continue;
                    if (!std.mem.eql(u8, imported, "forwardRef")) continue;
                    const local = bindingIdentifierName(tree, specifier.local) orelse continue;
                    try direct_imports.put(allocator, local, {});
                },
                .import_default_specifier => |specifier| {
                    const local = bindingIdentifierName(tree, specifier.local) orelse continue;
                    try namespace_imports.put(allocator, local, {});
                },
                .import_namespace_specifier => |specifier| {
                    const local = bindingIdentifierName(tree, specifier.local) orelse continue;
                    try namespace_imports.put(allocator, local, {});
                },
                else => {},
            }
        }
    }
}

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

fn memberPropertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.computed) return stringLiteralValue(tree, member.property);
    return propertyName(tree, member.property);
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn stringLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
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
