const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const export_map = @import("import_export_map.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "import/no-named-as-default-member";

const DefaultImport = struct {
    name: []const u8,
    source: []const u8,
    map: export_map.ExportMap,
};

pub fn run(
    allocator: Allocator,
    io: std.Io,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    file_path: []const u8,
) Allocator.Error!void {
    var imports = std.ArrayList(DefaultImport).empty;
    defer {
        for (imports.items) |*import| {
            import.map.deinit();
        }
        imports.deinit(allocator);
    }

    try collectDefaultImports(allocator, io, tree, file_path, &imports);
    if (imports.items.len == 0) return;

    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .imports = imports.items,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);
}

fn collectDefaultImports(
    allocator: Allocator,
    io: std.Io,
    tree: *const ast.Tree,
    file_path: []const u8,
    imports: *std.ArrayList(DefaultImport),
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
        const source = export_map.importSource(tree, declaration) orelse continue;

        for (tree.extra(declaration.specifiers)) |specifier_index| {
            const specifier = switch (tree.data(specifier_index)) {
                .import_default_specifier => |specifier| specifier,
                else => continue,
            };
            const local = bindingIdentifierName(tree, specifier.local) orelse continue;
            const resolved = try export_map.resolveRelativeModule(allocator, io, file_path, source) orelse continue;
            defer allocator.free(resolved);

            var remote = try export_map.readExportMap(allocator, io, resolved) orelse continue;
            errdefer remote.deinit();
            try imports.append(allocator, .{
                .name = local,
                .source = source,
                .map = remote,
            });
        }
    }
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    imports: []const DefaultImport,

    pub fn enter_member_expression(
        self: *Visitor,
        member: ast.MemberExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const object = identifierReferenceName(ctx.tree, member.object) orelse return .proceed;
        const property = memberPropertyName(ctx.tree, member) orelse return .proceed;
        try self.reportIfNamedExport(ctx.tree, index, object, property);
        return .proceed;
    }

    pub fn enter_variable_declarator(
        self: *Visitor,
        declarator: ast.VariableDeclarator,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const object = identifierReferenceName(ctx.tree, declarator.init) orelse return .proceed;
        const pattern = switch (ctx.tree.data(declarator.id)) {
            .object_pattern => |pattern| pattern,
            else => return .proceed,
        };

        for (ctx.tree.extra(pattern.properties)) |property_index| {
            const property = switch (ctx.tree.data(property_index)) {
                .binding_property => |property| property,
                else => continue,
            };
            if (property.computed) continue;
            const key = moduleExportName(ctx.tree, property.key) orelse continue;
            try self.reportIfNamedExport(ctx.tree, property.key, object, key);
        }
        return .proceed;
    }

    fn reportIfNamedExport(
        self: *Visitor,
        tree: *const ast.Tree,
        node: ast.NodeIndex,
        object: []const u8,
        property: []const u8,
    ) Allocator.Error!void {
        if (std.mem.eql(u8, property, "default")) return;
        const import = self.findDefaultImport(object) orelse return;
        if (!import.map.hasNamed(property)) return;

        try core.addDiagnosticFmt(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            tree.span(node),
            "Caution: `{s}` also has a named export `{s}`. Check if you meant to write `import {{{s}}} from '{s}'` instead.",
            .{ object, property, property, import.source },
        );
    }

    fn findDefaultImport(self: *Visitor, name: []const u8) ?*const DefaultImport {
        for (self.imports) |*import| {
            if (std.mem.eql(u8, import.name, name)) return import;
        }
        return null;
    }
};

fn memberPropertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.computed) return null;
    return moduleExportName(tree, member.property);
}

fn moduleExportName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
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

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}
