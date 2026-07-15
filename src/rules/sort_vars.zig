const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "sort-vars";

pub const Options = struct {
    ignore_case: bool = false,
};

pub fn checkVariableDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    options: Options,
) Allocator.Error!void {
    var previous_name: ?[]const u8 = null;
    var fix_considered = false;

    for (tree.extra(declaration.declarators)) |declarator_index| {
        const declarator = switch (tree.data(declarator_index)) {
            .variable_declarator => |declarator| declarator,
            else => continue,
        };
        const name = bindingIdentifierName(tree, declarator.id) orelse continue;

        if (previous_name) |previous| {
            if (compareNames(name, previous, options.ignore_case) < 0) {
                const fix = if (!fix_considered) fix: {
                    fix_considered = true;
                    break :fix try buildFix(allocator, tree, declaration, options);
                } else null;
                defer if (fix) |value| allocator.free(value.replacement);

                if (fix) |value| {
                    try core.addDiagnosticWithFix(
                        allocator,
                        diagnostics,
                        .warning,
                        id,
                        "Variables within the same declaration block should be sorted alphabetically.",
                        tree.span(declarator.id),
                        value,
                    );
                } else {
                    try core.addDiagnostic(
                        allocator,
                        diagnostics,
                        .warning,
                        id,
                        "Variables within the same declaration block should be sorted alphabetically.",
                        tree.span(declarator.id),
                    );
                }
                continue;
            }
        }

        previous_name = name;
    }
}

fn buildFix(
    allocator: Allocator,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    options: Options,
) Allocator.Error!?core.Fix {
    var declarators: std.ArrayList(ast.NodeIndex) = .empty;
    defer declarators.deinit(allocator);

    for (tree.extra(declaration.declarators)) |index| {
        const declarator = switch (tree.data(index)) {
            .variable_declarator => |value| value,
            else => continue,
        };
        if (bindingIdentifierName(tree, declarator.id) == null) continue;
        if (declarator.init != .null and !isLiteralInitializer(tree, declarator.init)) return null;
        try declarators.append(allocator, index);
    }
    if (declarators.items.len < 2) return null;

    const sorted = try allocator.dupe(ast.NodeIndex, declarators.items);
    defer allocator.free(sorted);
    stableSortDeclarators(tree, sorted, options.ignore_case);

    var replacement: std.ArrayList(u8) = .empty;
    errdefer replacement.deinit(allocator);

    for (sorted, 0..) |index, sorted_index| {
        const span = tree.span(index);
        try replacement.appendSlice(allocator, sourceForSpan(tree, span));

        if (sorted_index + 1 < sorted.len) {
            const original_span = tree.span(declarators.items[sorted_index]);
            const next_original_span = tree.span(declarators.items[sorted_index + 1]);
            try replacement.appendSlice(
                allocator,
                tree.source[@intCast(original_span.end)..@intCast(next_original_span.start)],
            );
        }
    }

    return .{
        .span = .{
            .start = tree.span(declarators.items[0]).start,
            .end = tree.span(declarators.items[declarators.items.len - 1]).end,
        },
        .replacement = try replacement.toOwnedSlice(allocator),
    };
}

fn stableSortDeclarators(tree: *const ast.Tree, declarators: []ast.NodeIndex, ignore_case: bool) void {
    var index: usize = 1;
    while (index < declarators.len) : (index += 1) {
        const current = declarators[index];
        const current_name = declaratorName(tree, current);
        var insertion = index;
        while (insertion > 0 and compareNames(current_name, declaratorName(tree, declarators[insertion - 1]), ignore_case) < 0) {
            declarators[insertion] = declarators[insertion - 1];
            insertion -= 1;
        }
        declarators[insertion] = current;
    }
}

fn declaratorName(tree: *const ast.Tree, index: ast.NodeIndex) []const u8 {
    const declarator = tree.data(index).variable_declarator;
    return bindingIdentifierName(tree, declarator.id).?;
}

fn isLiteralInitializer(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapParentheses(tree, index))) {
        .string_literal,
        .numeric_literal,
        .bigint_literal,
        .boolean_literal,
        .null_literal,
        .regexp_literal,
        => true,
        else => false,
    };
}

fn unwrapParentheses(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;
    while (tree.data(current) == .parenthesized_expression) {
        current = tree.data(current).parenthesized_expression.expression;
    }
    return current;
}

fn sourceForSpan(tree: *const ast.Tree, span: ast.Span) []const u8 {
    return tree.source[@intCast(span.start)..@intCast(span.end)];
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn compareNames(left: []const u8, right: []const u8, ignore_case: bool) i8 {
    const min_len = @min(left.len, right.len);
    for (0..min_len) |index| {
        const left_char = normalizeChar(left[index], ignore_case);
        const right_char = normalizeChar(right[index], ignore_case);
        if (left_char < right_char) return -1;
        if (left_char > right_char) return 1;
    }

    if (left.len < right.len) return -1;
    if (left.len > right.len) return 1;
    return 0;
}

fn normalizeChar(char: u8, ignore_case: bool) u8 {
    return if (ignore_case) std.ascii.toLower(char) else char;
}
