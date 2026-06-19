const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-restricted-exports";

pub const Options = struct {
    names: *const core.NoRestrictedExportNames,
    restrict_default: core.NoRestrictedExportsDefaultOptions = .{},
};

pub fn checkExportDefaultDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (options.names.contains("default")) {
        try reportRestrictedNamed(allocator, diagnostics, tree, index, "default");
        return;
    }

    if (options.restrict_default.direct) {
        try reportRestrictedDefault(allocator, diagnostics, tree, index);
    }
}

pub fn checkExportAllDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.ExportAllDeclaration,
    _: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (declaration.export_kind == .type) return;
    if (declaration.exported == .null) return;

    const name = moduleExportName(tree, declaration.exported) orelse return;
    if (try checkNamedExport(allocator, diagnostics, tree, declaration.exported, name, options)) return;

    if (std.mem.eql(u8, name, "default") and options.restrict_default.namespace_from) {
        try reportRestrictedDefault(allocator, diagnostics, tree, declaration.exported);
    }
}

pub fn checkExportNamedDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.ExportNamedDeclaration,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (declaration.export_kind == .type) return;

    if (declaration.declaration != .null) {
        try checkDeclarationNames(allocator, diagnostics, tree, declaration.declaration, index, options);
    }

    const has_source = declaration.source != .null;
    for (tree.extra(declaration.specifiers)) |specifier_index| {
        const specifier = switch (tree.data(specifier_index)) {
            .export_specifier => |specifier| specifier,
            else => continue,
        };
        if (specifier.export_kind == .type) continue;

        const exported = moduleExportName(tree, specifier.exported) orelse continue;
        if (try checkNamedExport(allocator, diagnostics, tree, specifier.exported, exported, options)) continue;

        if (!std.mem.eql(u8, exported, "default")) continue;
        const local = moduleExportName(tree, specifier.local) orelse continue;

        if (!has_source and options.restrict_default.named) {
            try reportRestrictedDefault(allocator, diagnostics, tree, specifier.exported);
        } else if (has_source and std.mem.eql(u8, local, "default") and options.restrict_default.default_from) {
            try reportRestrictedDefault(allocator, diagnostics, tree, specifier.exported);
        } else if (has_source and !std.mem.eql(u8, local, "default") and options.restrict_default.named_from) {
            try reportRestrictedDefault(allocator, diagnostics, tree, specifier.exported);
        }
    }
}

fn checkDeclarationNames(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration_index: ast.NodeIndex,
    report_node: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    switch (tree.data(declaration_index)) {
        .variable_declaration => |declaration| {
            for (tree.extra(declaration.declarators)) |declarator_index| {
                const declarator = switch (tree.data(declarator_index)) {
                    .variable_declarator => |declarator| declarator,
                    else => continue,
                };
                try checkBindingNames(allocator, diagnostics, tree, declarator.id, options);
            }
        },
        .function => |function| if (bindingIdentifierName(tree, function.id)) |name| {
            _ = try checkNamedExport(allocator, diagnostics, tree, function.id, name, options);
        },
        .class => |class| if (bindingIdentifierName(tree, class.id)) |name| {
            _ = try checkNamedExport(allocator, diagnostics, tree, class.id, name, options);
        },
        .ts_type_alias_declaration => |declaration| if (bindingIdentifierName(tree, declaration.id)) |name| {
            _ = try checkNamedExport(allocator, diagnostics, tree, declaration.id, name, options);
        },
        .ts_interface_declaration => |declaration| if (bindingIdentifierName(tree, declaration.id)) |name| {
            _ = try checkNamedExport(allocator, diagnostics, tree, declaration.id, name, options);
        },
        .ts_enum_declaration => |declaration| if (bindingIdentifierName(tree, declaration.id)) |name| {
            _ = try checkNamedExport(allocator, diagnostics, tree, declaration.id, name, options);
        },
        .ts_module_declaration => |declaration| if (bindingIdentifierName(tree, declaration.id)) |name| {
            _ = try checkNamedExport(allocator, diagnostics, tree, declaration.id, name, options);
        },
        else => {
            if (options.names.contains("default")) {
                try reportRestrictedNamed(allocator, diagnostics, tree, report_node, "default");
            }
        },
    }
}

fn checkBindingNames(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (index == .null) return;
    switch (tree.data(index)) {
        .binding_identifier => |identifier| {
            const name = tree.string(identifier.name);
            _ = try checkNamedExport(allocator, diagnostics, tree, index, name, options);
        },
        .assignment_pattern => |pattern| try checkBindingNames(allocator, diagnostics, tree, pattern.left, options),
        .binding_rest_element => |element| try checkBindingNames(allocator, diagnostics, tree, element.argument, options),
        .array_pattern => |pattern| {
            for (tree.extra(pattern.elements)) |element| {
                try checkBindingNames(allocator, diagnostics, tree, element, options);
            }
            try checkBindingNames(allocator, diagnostics, tree, pattern.rest, options);
        },
        .object_pattern => |pattern| {
            for (tree.extra(pattern.properties)) |property_index| {
                const property = switch (tree.data(property_index)) {
                    .binding_property => |property| property,
                    else => continue,
                };
                try checkBindingNames(allocator, diagnostics, tree, property.value, options);
            }
            try checkBindingNames(allocator, diagnostics, tree, pattern.rest, options);
        },
        else => {},
    }
}

fn checkNamedExport(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    name: []const u8,
    options: Options,
) Allocator.Error!bool {
    if (!options.names.contains(name)) return false;
    try reportRestrictedNamed(allocator, diagnostics, tree, index, name);
    return true;
}

fn moduleExportName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
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

fn reportRestrictedNamed(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    name: []const u8,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "'{s}' is restricted from being used as an exported name.",
        .{name},
    );
}

fn reportRestrictedDefault(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Exporting 'default' is restricted.",
        tree.span(index),
    );
}
