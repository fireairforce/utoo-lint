const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const export_map = @import("import_export_map.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "import/export";

const ExportNode = struct {
    name: []const u8,
    node: ast.NodeIndex,
};

const EmptyExportAll = struct {
    source: []const u8,
    node: ast.NodeIndex,
};

const NamedList = std.ArrayList(ExportNode);

const ExportState = struct {
    allocator: Allocator,
    exports: std.StringHashMap(NamedList),
    order: std.ArrayList([]const u8),
    empty_export_alls: std.ArrayList(EmptyExportAll),

    fn init(allocator: Allocator) ExportState {
        return .{
            .allocator = allocator,
            .exports = std.StringHashMap(NamedList).init(allocator),
            .order = .empty,
            .empty_export_alls = .empty,
        };
    }

    fn deinit(self: *ExportState) void {
        for (self.order.items) |name| {
            if (self.exports.getPtr(name)) |nodes| nodes.deinit(self.allocator);
            self.allocator.free(name);
        }
        self.exports.deinit();
        self.order.deinit(self.allocator);
        self.empty_export_alls.deinit(self.allocator);
    }

    fn add(self: *ExportState, name: []const u8, node: ast.NodeIndex) Allocator.Error!void {
        const gop = try self.exports.getOrPut(name);
        if (!gop.found_existing) {
            const owned = try self.allocator.dupe(u8, name);
            errdefer self.allocator.free(owned);
            gop.key_ptr.* = owned;
            gop.value_ptr.* = .empty;
            try self.order.append(self.allocator, owned);
        }
        try gop.value_ptr.append(self.allocator, .{
            .name = gop.key_ptr.*,
            .node = node,
        });
    }

    fn addEmptyExportAll(self: *ExportState, source: []const u8, node: ast.NodeIndex) Allocator.Error!void {
        try self.empty_export_alls.append(self.allocator, .{
            .source = source,
            .node = node,
        });
    }
};

pub fn run(
    allocator: Allocator,
    io: std.Io,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    file_path: []const u8,
) Allocator.Error!void {
    const program = switch (tree.data(tree.root)) {
        .program => |program| program,
        else => return,
    };

    var state = ExportState.init(allocator);
    defer state.deinit();

    for (tree.extra(program.body)) |statement_index| {
        switch (tree.data(statement_index)) {
            .export_default_declaration => try state.add("default", statement_index),
            .export_named_declaration => |declaration| try collectNamedDeclaration(
                allocator,
                io,
                tree,
                file_path,
                declaration,
                statement_index,
                &state,
            ),
            .export_all_declaration => |declaration| try collectExportAll(
                allocator,
                io,
                tree,
                file_path,
                declaration,
                statement_index,
                &state,
            ),
            else => {},
        }
    }

    try reportDuplicates(allocator, diagnostics, tree, &state);
    try reportEmptyExportAlls(allocator, diagnostics, tree, &state);
}

fn collectNamedDeclaration(
    allocator: Allocator,
    io: std.Io,
    tree: *const ast.Tree,
    file_path: []const u8,
    declaration: ast.ExportNamedDeclaration,
    declaration_index: ast.NodeIndex,
    state: *ExportState,
) Allocator.Error!void {
    if (declaration.export_kind == .type) return;

    if (exportNamedSource(tree, declaration)) |source| {
        var remote = try readRemoteMap(allocator, io, file_path, source) orelse return;
        defer remote.deinit();

        for (tree.extra(declaration.specifiers)) |specifier_index| {
            const specifier = switch (tree.data(specifier_index)) {
                .export_specifier => |specifier| specifier,
                else => continue,
            };
            if (specifier.export_kind == .type) continue;
            const local = moduleExportName(tree, specifier.local) orelse continue;
            if (!remote.hasNamed(local)) continue;
            const exported = moduleExportName(tree, specifier.exported) orelse continue;
            try state.add(exported, specifier.exported);
        }
        return;
    }

    for (tree.extra(declaration.specifiers)) |specifier_index| {
        const specifier = switch (tree.data(specifier_index)) {
            .export_specifier => |specifier| specifier,
            else => continue,
        };
        if (specifier.export_kind == .type) continue;
        const exported = moduleExportName(tree, specifier.exported) orelse continue;
        try state.add(exported, specifier.exported);
    }

    if (declaration.declaration == .null) return;
    try collectDeclarationNames(allocator, tree, declaration.declaration, declaration_index, state);
}

fn collectExportAll(
    allocator: Allocator,
    io: std.Io,
    tree: *const ast.Tree,
    file_path: []const u8,
    declaration: ast.ExportAllDeclaration,
    declaration_index: ast.NodeIndex,
    state: *ExportState,
) Allocator.Error!void {
    if (declaration.export_kind == .type) return;
    if (declaration.exported != .null) return;

    const source = exportAllSource(tree, declaration) orelse return;
    var remote = try readRemoteMap(allocator, io, file_path, source) orelse return;
    defer remote.deinit();

    var has_named = false;
    var iter = remote.named.iterator();
    while (iter.next()) |entry| {
        has_named = true;
        try state.add(entry.key_ptr.*, declaration_index);
    }

    if (!has_named) {
        try state.addEmptyExportAll(source, declaration.source);
    }
}

fn reportDuplicates(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    state: *const ExportState,
) Allocator.Error!void {
    for (state.order.items) |name| {
        const nodes = state.exports.get(name) orelse continue;
        if (nodes.items.len <= 1) continue;

        for (nodes.items) |export_node| {
            if (std.mem.eql(u8, export_node.name, "default")) {
                try core.addDiagnostic(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    "Multiple default exports.",
                    tree.span(export_node.node),
                );
            } else {
                try core.addDiagnosticFmt(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    tree.span(export_node.node),
                    "Multiple exports of name '{s}'.",
                    .{export_node.name},
                );
            }
        }
    }
}

fn reportEmptyExportAlls(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    state: *const ExportState,
) Allocator.Error!void {
    for (state.empty_export_alls.items) |empty_export| {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(empty_export.node),
            "No named exports found in module '{s}'.",
            .{empty_export.source},
        );
    }
}

fn collectDeclarationNames(
    allocator: Allocator,
    tree: *const ast.Tree,
    declaration_index: ast.NodeIndex,
    report_node: ast.NodeIndex,
    state: *ExportState,
) Allocator.Error!void {
    switch (tree.data(declaration_index)) {
        .variable_declaration => |declaration| {
            for (tree.extra(declaration.declarators)) |declarator_index| {
                const declarator = switch (tree.data(declarator_index)) {
                    .variable_declarator => |declarator| declarator,
                    else => continue,
                };
                try collectBindingNames(allocator, tree, declarator.id, report_node, state);
            }
        },
        .function => |function| {
            const name = bindingIdentifierName(tree, function.id) orelse return;
            try state.add(name, report_node);
        },
        .class => |class| {
            const name = bindingIdentifierName(tree, class.id) orelse return;
            try state.add(name, report_node);
        },
        .ts_type_alias_declaration => |declaration| try state.add(bindingIdentifierName(tree, declaration.id) orelse return, report_node),
        .ts_interface_declaration => |declaration| try state.add(bindingIdentifierName(tree, declaration.id) orelse return, report_node),
        .ts_enum_declaration => |declaration| try state.add(bindingIdentifierName(tree, declaration.id) orelse return, report_node),
        .ts_module_declaration => |declaration| try state.add(bindingIdentifierName(tree, declaration.id) orelse return, report_node),
        else => {},
    }
}

fn collectBindingNames(
    allocator: Allocator,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    report_node: ast.NodeIndex,
    state: *ExportState,
) Allocator.Error!void {
    if (index == .null) return;
    switch (tree.data(index)) {
        .binding_identifier => |identifier| try state.add(tree.string(identifier.name), report_node),
        .assignment_pattern => |pattern| try collectBindingNames(allocator, tree, pattern.left, report_node, state),
        .binding_rest_element => |element| try collectBindingNames(allocator, tree, element.argument, report_node, state),
        .array_pattern => |pattern| {
            for (tree.extra(pattern.elements)) |element| {
                try collectBindingNames(allocator, tree, element, report_node, state);
            }
            try collectBindingNames(allocator, tree, pattern.rest, report_node, state);
        },
        .object_pattern => |pattern| {
            for (tree.extra(pattern.properties)) |property_index| {
                const property = switch (tree.data(property_index)) {
                    .binding_property => |property| property,
                    else => continue,
                };
                try collectBindingNames(allocator, tree, property.value, report_node, state);
            }
            try collectBindingNames(allocator, tree, pattern.rest, report_node, state);
        },
        else => {},
    }
}

fn readRemoteMap(
    allocator: Allocator,
    io: std.Io,
    file_path: []const u8,
    source: []const u8,
) Allocator.Error!?export_map.ExportMap {
    const resolved = try export_map.resolveRelativeModule(allocator, io, file_path, source) orelse return null;
    defer allocator.free(resolved);
    return export_map.readExportMap(allocator, io, resolved);
}

fn exportNamedSource(tree: *const ast.Tree, declaration: ast.ExportNamedDeclaration) ?[]const u8 {
    if (declaration.source == .null) return null;
    return switch (tree.data(declaration.source)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn exportAllSource(tree: *const ast.Tree, declaration: ast.ExportAllDeclaration) ?[]const u8 {
    if (declaration.source == .null) return null;
    return switch (tree.data(declaration.source)) {
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn moduleExportName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
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
