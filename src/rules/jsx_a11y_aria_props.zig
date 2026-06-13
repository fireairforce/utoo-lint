const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "jsx-a11y/aria-props";

const valid_aria_attributes = [_][]const u8{
    "aria-activedescendant",
    "aria-atomic",
    "aria-autocomplete",
    "aria-braillelabel",
    "aria-brailleroledescription",
    "aria-busy",
    "aria-checked",
    "aria-colcount",
    "aria-colindex",
    "aria-colspan",
    "aria-controls",
    "aria-current",
    "aria-describedby",
    "aria-description",
    "aria-details",
    "aria-disabled",
    "aria-dropeffect",
    "aria-errormessage",
    "aria-expanded",
    "aria-flowto",
    "aria-grabbed",
    "aria-haspopup",
    "aria-hidden",
    "aria-invalid",
    "aria-keyshortcuts",
    "aria-label",
    "aria-labelledby",
    "aria-level",
    "aria-live",
    "aria-modal",
    "aria-multiline",
    "aria-multiselectable",
    "aria-orientation",
    "aria-owns",
    "aria-placeholder",
    "aria-posinset",
    "aria-pressed",
    "aria-readonly",
    "aria-relevant",
    "aria-required",
    "aria-roledescription",
    "aria-rowcount",
    "aria-rowindex",
    "aria-rowspan",
    "aria-selected",
    "aria-setsize",
    "aria-sort",
    "aria-valuemax",
    "aria-valuemin",
    "aria-valuenow",
    "aria-valuetext",
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    attribute: ast.JSXAttribute,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const name = attributeName(tree, attribute.name) orelse return;
    if (!std.mem.startsWith(u8, name, "aria-")) return;
    if (isValidAriaAttribute(name)) return;

    if (suggestion(name)) |suggested| {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "{s}: This attribute is an invalid ARIA attribute. Did you mean to use {s}?",
            .{ name, suggested },
        );
        return;
    }

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "{s}: This attribute is an invalid ARIA attribute.",
        .{name},
    );
}

fn attributeName(tree: *const ast.Tree, name_index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isValidAriaAttribute(name: []const u8) bool {
    for (valid_aria_attributes) |attribute| {
        if (std.mem.eql(u8, name, attribute)) return true;
    }
    return false;
}

fn suggestion(name: []const u8) ?[]const u8 {
    var best_distance: usize = 3;
    var best: ?[]const u8 = null;

    for (valid_aria_attributes) |attribute| {
        const distance = damerauLevenshteinDistance(name, attribute, 2);
        if (distance <= 2 and distance < best_distance) {
            best_distance = distance;
            best = attribute;
        }
    }

    return best;
}

fn damerauLevenshteinDistance(a: []const u8, b: []const u8, max_distance: usize) usize {
    var matrix: [64][64]usize = undefined;
    const a_len = a.len;
    const b_len = b.len;
    if (a_len >= matrix.len or b_len >= matrix[0].len) return max_distance + 1;

    for (0..a_len + 1) |i| matrix[i][0] = i;
    for (0..b_len + 1) |j| matrix[0][j] = j;

    for (1..a_len + 1) |i| {
        var row_min: usize = max_distance + 1;
        for (1..b_len + 1) |j| {
            const cost: usize = if (std.ascii.toUpper(a[i - 1]) == std.ascii.toUpper(b[j - 1])) 0 else 1;
            var value = @min(
                @min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
                matrix[i - 1][j - 1] + cost,
            );

            if (i > 1 and j > 1 and
                std.ascii.toUpper(a[i - 1]) == std.ascii.toUpper(b[j - 2]) and
                std.ascii.toUpper(a[i - 2]) == std.ascii.toUpper(b[j - 1]))
            {
                value = @min(value, matrix[i - 2][j - 2] + 1);
            }

            matrix[i][j] = value;
            row_min = @min(row_min, value);
        }
        if (row_min > max_distance and i > max_distance) return max_distance + 1;
    }

    return matrix[a_len][b_len];
}
