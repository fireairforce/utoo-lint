const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "react/no-danger";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    attribute: ast.JSXAttribute,
    index: ast.NodeIndex,
    parent_index: ?ast.NodeIndex,
) Allocator.Error!void {
    if (!isDangerousAttribute(tree, attribute.name)) return;

    const opening = switch (tree.data(parent_index orelse return)) {
        .jsx_opening_element => |opening| opening,
        else => return,
    };
    if (!isDomComponent(tree, opening.name)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Dangerous property '{s}' found",
        .{"dangerouslySetInnerHTML"},
    );
}

fn isDangerousAttribute(tree: *const ast.Tree, name_index: ast.NodeIndex) bool {
    return switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| std.mem.eql(u8, tree.string(identifier.name), "dangerouslySetInnerHTML"),
        else => false,
    };
}

fn isDomComponent(tree: *const ast.Tree, name_index: ast.NodeIndex) bool {
    const root = jsxNameRoot(tree, name_index) orelse return false;
    const name = switch (tree.data(root)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => return false,
    };
    return name.len > 0 and name[0] >= 'a' and name[0] <= 'z';
}

fn jsxNameRoot(tree: *const ast.Tree, name_index: ast.NodeIndex) ?ast.NodeIndex {
    var current = name_index;
    while (current != .null) {
        switch (tree.data(current)) {
            .jsx_identifier => return current,
            .jsx_namespaced_name => |name| return name.namespace,
            .jsx_member_expression => |member| current = member.object,
            else => return null,
        }
    }
    return null;
}
