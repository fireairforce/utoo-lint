const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "sort-imports";

pub const Options = struct {
    ignore_case: bool = false,
    ignore_declaration_sort: bool = false,
    ignore_member_sort: bool = false,
    allow_separated_groups: bool = false,
    member_syntax_order: core.SortImportsMemberSyntaxOrder = .{},
};

const ImportKey = struct {
    syntax: core.SortImportsMemberSyntax,
    name: []const u8,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    program: ast.Program,
    options: Options,
) Allocator.Error!void {
    var previous_import: ast.NodeIndex = .null;
    var previous_key: ?ImportKey = null;

    for (tree.extra(program.body)) |statement_index| {
        const declaration = switch (tree.data(statement_index)) {
            .import_declaration => |declaration| declaration,
            else => continue,
        };

        if (!options.ignore_member_sort) {
            try checkMemberSort(allocator, diagnostics, tree, declaration, options);
        }

        if (!options.ignore_declaration_sort) {
            const key = importKey(tree, declaration);
            if (previous_key) |last_key| {
                if (options.allow_separated_groups and importsAreSeparated(tree, previous_import, statement_index)) {
                    previous_key = key;
                    previous_import = statement_index;
                    continue;
                }
                if (compareImportKeys(last_key, key, options) > 0) {
                    try core.addDiagnostic(
                        allocator,
                        diagnostics,
                        .warning,
                        id,
                        "Imports should be sorted.",
                        tree.span(statement_index),
                    );
                }
            }
            previous_key = key;
            previous_import = statement_index;
        }
    }
}

fn checkMemberSort(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.ImportDeclaration,
    options: Options,
) Allocator.Error!void {
    var previous_name: ?[]const u8 = null;

    for (tree.extra(declaration.specifiers)) |specifier_index| {
        const specifier = switch (tree.data(specifier_index)) {
            .import_specifier => |specifier| specifier,
            else => continue,
        };
        const name = moduleName(tree, specifier.imported) orelse continue;
        if (previous_name) |last_name| {
            if (compareNames(last_name, name, options.ignore_case) > 0) {
                try core.addDiagnostic(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    "Member imports should be sorted.",
                    tree.span(specifier.imported),
                );
                return;
            }
        }
        previous_name = name;
    }
}

fn importKey(tree: *const ast.Tree, declaration: ast.ImportDeclaration) ImportKey {
    var first_name: []const u8 = "";
    var named_count: usize = 0;
    var has_default = false;
    var has_namespace = false;

    for (tree.extra(declaration.specifiers)) |specifier_index| {
        switch (tree.data(specifier_index)) {
            .import_default_specifier => |specifier| {
                has_default = true;
                if (first_name.len == 0) first_name = bindingName(tree, specifier.local) orelse "";
            },
            .import_namespace_specifier => |specifier| {
                has_namespace = true;
                if (first_name.len == 0) first_name = bindingName(tree, specifier.local) orelse "";
            },
            .import_specifier => |specifier| {
                named_count += 1;
                if (first_name.len == 0) first_name = moduleName(tree, specifier.imported) orelse "";
            },
            else => {},
        }
    }

    if (!has_default and !has_namespace and named_count == 0) {
        return .{ .syntax = .none, .name = "" };
    }
    if (!has_default and has_namespace and named_count == 0) {
        return .{ .syntax = .all, .name = first_name };
    }
    if (has_default and !has_namespace and named_count == 0) {
        return .{ .syntax = .single, .name = first_name };
    }
    return .{ .syntax = .multiple, .name = first_name };
}

fn compareImportKeys(left: ImportKey, right: ImportKey, options: Options) i8 {
    const left_rank = options.member_syntax_order.rank(left.syntax);
    const right_rank = options.member_syntax_order.rank(right.syntax);
    if (left_rank < right_rank) return -1;
    if (left_rank > right_rank) return 1;
    return compareNames(left.name, right.name, options.ignore_case);
}

fn compareNames(left: []const u8, right: []const u8, ignore_case: bool) i8 {
    const order = if (ignore_case)
        std.ascii.orderIgnoreCase(left, right)
    else
        std.mem.order(u8, left, right);
    return switch (order) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
}

fn importsAreSeparated(tree: *const ast.Tree, previous: ast.NodeIndex, current: ast.NodeIndex) bool {
    if (previous == .null or current == .null) return false;
    const previous_span = tree.span(previous);
    const current_span = tree.span(current);
    if (previous_span.end >= current_span.start) return false;

    const between = tree.source[previous_span.end..current_span.start];
    var newline_count: usize = 0;
    for (between) |char| {
        if (char == '\n') {
            newline_count += 1;
            if (newline_count >= 2) return true;
        } else if (char != '\r' and char != ' ' and char != '\t') {
            newline_count = 0;
        }
    }
    return false;
}

fn moduleName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => null,
    };
}

fn bindingName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}
