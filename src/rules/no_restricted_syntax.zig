const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-restricted-syntax";

pub fn checkNode(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    data: ast.NodeData,
    index: ast.NodeIndex,
    restrictions: core.NoRestrictedSyntax,
) Allocator.Error!void {
    if (restrictions.count == 0) return;

    const tag_name = @tagName(data);
    for (0..restrictions.count) |restriction_index| {
        const restriction = restrictions.at(restriction_index);
        if (!matchesSelector(restriction.selector(), tag_name)) continue;
        try addDiagnostic(allocator, diagnostics, tree, index, restriction);
    }
}

fn matchesSelector(selector: []const u8, tag_name: []const u8) bool {
    return std.mem.eql(u8, selector, tag_name) or normalizedEqual(selector, tag_name);
}

fn normalizedEqual(selector: []const u8, tag_name: []const u8) bool {
    var selector_index: usize = 0;
    var tag_index: usize = 0;

    while (true) {
        selector_index = nextComparable(selector, selector_index);
        tag_index = nextComparable(tag_name, tag_index);

        if (selector_index == selector.len or tag_index == tag_name.len) {
            return selector_index == selector.len and tag_index == tag_name.len;
        }

        if (std.ascii.toLower(selector[selector_index]) != std.ascii.toLower(tag_name[tag_index])) {
            return false;
        }

        selector_index += 1;
        tag_index += 1;
    }
}

fn nextComparable(value: []const u8, start: usize) usize {
    var index = start;
    while (index < value.len and (value[index] == '_' or value[index] == '-')) {
        index += 1;
    }
    return index;
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    restriction: *const core.NoRestrictedSyntaxEntry,
) Allocator.Error!void {
    if (restriction.message()) |message| {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "{s}",
            .{message},
        );
    } else {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "Using '{s}' is not allowed.",
            .{restriction.selector()},
        );
    }
}
