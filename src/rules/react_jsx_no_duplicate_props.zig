const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/jsx-no-duplicate-props";

pub const Options = struct {
    ignore_case: bool = true,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    opening: ast.JSXOpeningElement,
) Allocator.Error!void {
    return checkWithOptions(allocator, diagnostics, tree, opening, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    opening: ast.JSXOpeningElement,
    options: Options,
) Allocator.Error!void {
    var seen: std.ArrayList([]const u8) = .empty;
    defer seen.deinit(allocator);

    for (tree.extra(opening.attributes)) |attribute_index| {
        const attribute = switch (tree.data(attribute_index)) {
            .jsx_attribute => |attribute| attribute,
            else => continue,
        };
        const name = attributeName(tree, attribute.name) orelse continue;

        if (containsName(seen.items, name, options.ignore_case)) {
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

fn containsName(items: []const []const u8, name: []const u8, ignore_case: bool) bool {
    for (items) |item| {
        if (if (ignore_case) std.ascii.eqlIgnoreCase(item, name) else std.mem.eql(u8, item, name)) return true;
    }
    return false;
}
