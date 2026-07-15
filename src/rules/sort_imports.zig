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
            try checkMemberSort(allocator, diagnostics, tree, declaration, statement_index, options);
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
    declaration_index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    var previous_name: ?[]const u8 = null;

    for (tree.extra(declaration.specifiers)) |specifier_index| {
        const specifier = switch (tree.data(specifier_index)) {
            .import_specifier => |specifier| specifier,
            else => continue,
        };
        const name = bindingName(tree, specifier.local) orelse continue;
        if (previous_name) |last_name| {
            if (compareNames(last_name, name, options.ignore_case) > 0) {
                const fix = try buildMemberFix(allocator, tree, declaration, declaration_index, options);
                defer if (fix) |value| allocator.free(value.replacement);

                if (fix) |value| {
                    try core.addDiagnosticWithFix(
                        allocator,
                        diagnostics,
                        .warning,
                        id,
                        "Member imports should be sorted.",
                        tree.span(specifier.local),
                        value,
                    );
                } else {
                    try core.addDiagnostic(
                        allocator,
                        diagnostics,
                        .warning,
                        id,
                        "Member imports should be sorted.",
                        tree.span(specifier.local),
                    );
                }
                return;
            }
        }
        previous_name = name;
    }
}

fn buildMemberFix(
    allocator: Allocator,
    tree: *const ast.Tree,
    declaration: ast.ImportDeclaration,
    declaration_index: ast.NodeIndex,
    options: Options,
) Allocator.Error!?core.Fix {
    var specifiers: std.ArrayList(ast.NodeIndex) = .empty;
    defer specifiers.deinit(allocator);

    for (tree.extra(declaration.specifiers)) |index| {
        if (tree.data(index) == .import_specifier) try specifiers.append(allocator, index);
    }
    if (specifiers.items.len < 2) return null;
    if (memberListHasComment(tree, declaration, declaration_index, specifiers.items)) return null;

    const sorted = try allocator.dupe(ast.NodeIndex, specifiers.items);
    defer allocator.free(sorted);
    stableSortSpecifiers(tree, sorted, options.ignore_case);

    var replacement: std.ArrayList(u8) = .empty;
    errdefer replacement.deinit(allocator);

    for (sorted, 0..) |index, sorted_index| {
        try replacement.appendSlice(allocator, sourceForSpan(tree, tree.span(index)));

        if (sorted_index + 1 < sorted.len) {
            const original_span = tree.span(specifiers.items[sorted_index]);
            const next_original_span = tree.span(specifiers.items[sorted_index + 1]);
            try replacement.appendSlice(
                allocator,
                tree.source[@intCast(original_span.end)..@intCast(next_original_span.start)],
            );
        }
    }

    return .{
        .span = .{
            .start = tree.span(specifiers.items[0]).start,
            .end = tree.span(specifiers.items[specifiers.items.len - 1]).end,
        },
        .replacement = try replacement.toOwnedSlice(allocator),
    };
}

fn memberListHasComment(
    tree: *const ast.Tree,
    declaration: ast.ImportDeclaration,
    declaration_index: ast.NodeIndex,
    specifiers: []const ast.NodeIndex,
) bool {
    const declaration_start = tree.span(declaration_index).start;
    const first_start = tree.span(specifiers[0]).start;
    const last_end = tree.span(specifiers[specifiers.len - 1]).end;
    const source_start = tree.span(declaration.source).start;

    const before_first = tree.source[@intCast(declaration_start)..@intCast(first_start)];
    const opening = std.mem.lastIndexOfScalar(u8, before_first, '{') orelse return true;
    const after_last = tree.source[@intCast(last_end)..@intCast(source_start)];
    const closing_offset = std.mem.indexOfScalar(u8, after_last, '}') orelse return true;
    const closing = last_end + @as(u32, @intCast(closing_offset));

    return hasCommentBetween(tree, declaration_start + @as(u32, @intCast(opening + 1)), closing);
}

fn hasCommentBetween(tree: *const ast.Tree, start: u32, end: u32) bool {
    for (tree.comments) |comment| {
        if (comment.span.end <= start) continue;
        if (comment.span.start >= end) break;
        return true;
    }
    return false;
}

fn stableSortSpecifiers(tree: *const ast.Tree, specifiers: []ast.NodeIndex, ignore_case: bool) void {
    var index: usize = 1;
    while (index < specifiers.len) : (index += 1) {
        const current = specifiers[index];
        const current_name = specifierLocalName(tree, current);
        var insertion = index;
        while (insertion > 0 and compareNames(current_name, specifierLocalName(tree, specifiers[insertion - 1]), ignore_case) < 0) {
            specifiers[insertion] = specifiers[insertion - 1];
            insertion -= 1;
        }
        specifiers[insertion] = current;
    }
}

fn specifierLocalName(tree: *const ast.Tree, index: ast.NodeIndex) []const u8 {
    const specifier = tree.data(index).import_specifier;
    return bindingName(tree, specifier.local).?;
}

fn sourceForSpan(tree: *const ast.Tree, span: ast.Span) []const u8 {
    return tree.source[@intCast(span.start)..@intCast(span.end)];
}

fn importKey(tree: *const ast.Tree, declaration: ast.ImportDeclaration) ImportKey {
    const specifiers = tree.extra(declaration.specifiers);
    if (specifiers.len == 0) return .{ .syntax = .none, .name = "" };

    const first = tree.data(specifiers[0]);
    const name = switch (first) {
        .import_default_specifier => |specifier| bindingName(tree, specifier.local) orelse "",
        .import_namespace_specifier => |specifier| bindingName(tree, specifier.local) orelse "",
        .import_specifier => |specifier| bindingName(tree, specifier.local) orelse "",
        else => "",
    };
    if (first == .import_namespace_specifier) return .{ .syntax = .all, .name = name };
    return .{ .syntax = if (specifiers.len == 1) .single else .multiple, .name = name };
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

fn bindingName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}
