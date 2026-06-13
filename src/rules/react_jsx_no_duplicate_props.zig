const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/jsx-no-duplicate-props";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    opening: ast.JSXOpeningElement,
) Allocator.Error!void {
    var seen: std.ArrayList([]const u8) = .empty;
    defer seen.deinit(allocator);

    for (tree.extra(opening.attributes)) |attribute_index| {
        const attribute = switch (tree.data(attribute_index)) {
            .jsx_attribute => |attribute| attribute,
            else => continue,
        };
        const name = attributeName(tree, attribute.name) orelse continue;

        if (containsIgnoreCase(seen.items, name)) {
            try core.addDiagnostic(
                allocator,
                diagnostics,
                .@"error",
                id,
                "No duplicate props allowed",
                tree.span(attribute_index),
            );
            continue;
        }

        try seen.append(allocator, name);
    }
}

fn attributeName(tree: *const ast.Tree, name_index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn containsIgnoreCase(items: []const []const u8, name: []const u8) bool {
    for (items) |item| {
        if (std.ascii.eqlIgnoreCase(item, name)) return true;
    }
    return false;
}
