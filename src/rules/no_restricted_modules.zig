const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-restricted-modules";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
    restrictions: core.NoRestrictedModules,
) Allocator.Error!void {
    if (restrictions.count == 0) return;
    if (!isRequireCallee(tree, call.callee)) return;

    const source = firstStaticStringArgument(tree, call.arguments) orelse return;
    const entry = matchingRestriction(&restrictions, source) orelse return;

    try reportModule(allocator, diagnostics, tree, index, source, entry);
}

fn isRequireCallee(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), "require"),
        else => false,
    };
}

fn firstStaticStringArgument(tree: *const ast.Tree, arguments: ast.IndexRange) ?[]const u8 {
    if (arguments.len == 0) return null;

    return switch (tree.data(unwrapTransparent(tree, tree.extra(arguments)[0]))) {
        .string_literal => |literal| tree.string(literal.value),
        .template_literal => |literal| templateStringValue(tree, literal),
        else => null,
    };
}

fn templateStringValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;

    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return "";

    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
}

fn matchingRestriction(restrictions: *const core.NoRestrictedModules, source: []const u8) ?*const core.NoRestrictedImportEntry {
    var matched_pattern: ?*const core.NoRestrictedImportEntry = null;

    for (0..restrictions.count) |restriction_index| {
        const entry = restrictions.at(restriction_index);
        const pattern = entry.source();

        switch (entry.kind) {
            .path => {
                if (std.mem.eql(u8, pattern, source)) return entry;
            },
            .pattern => {
                if (std.mem.startsWith(u8, pattern, "!")) {
                    if (wildcardMatches(pattern[1..], source)) matched_pattern = null;
                } else if (wildcardMatches(pattern, source)) {
                    matched_pattern = entry;
                }
            },
        }
    }

    return matched_pattern;
}

fn wildcardMatches(pattern: []const u8, source: []const u8) bool {
    if (pattern.len == 0) return false;
    if (std.mem.indexOfScalar(u8, pattern, '*') == null) {
        return std.mem.eql(u8, pattern, source);
    }

    var source_index: usize = 0;
    var part_index: usize = 0;
    var parts = std.mem.splitScalar(u8, pattern, '*');
    while (parts.next()) |part| : (part_index += 1) {
        if (part.len == 0) continue;

        if (part_index == 0 and pattern[0] != '*') {
            if (!std.mem.startsWith(u8, source, part)) return false;
            source_index = part.len;
            continue;
        }

        const found = std.mem.indexOf(u8, source[source_index..], part) orelse return false;
        source_index += found + part.len;
    }

    if (pattern[pattern.len - 1] != '*') {
        var last_parts = std.mem.splitScalar(u8, pattern, '*');
        var last: []const u8 = "";
        while (last_parts.next()) |part| {
            if (part.len > 0) last = part;
        }
        return std.mem.endsWith(u8, source, last);
    }

    return true;
}

fn reportModule(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    node: ast.NodeIndex,
    source: []const u8,
    entry: *const core.NoRestrictedImportEntry,
) Allocator.Error!void {
    if (entry.message()) |message| {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(node),
            "'{s}' module is restricted from being used. {s}",
            .{ source, message },
        );
        return;
    }

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(node),
        "'{s}' module is restricted from being used.",
        .{source},
    );
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
