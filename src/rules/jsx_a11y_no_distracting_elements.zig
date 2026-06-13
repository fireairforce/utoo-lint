const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "jsx-a11y/no-distracting-elements";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    opening: ast.JSXOpeningElement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const element = distractingElement(tree, opening.name) orelse return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Do not use <{s}> elements as they can create visual accessibility issues and are deprecated.",
        .{element},
    );
}

fn distractingElement(tree: *const ast.Tree, name_index: ast.NodeIndex) ?[]const u8 {
    const name = switch (tree.data(name_index)) {
        .jsx_identifier => |identifier| tree.string(identifier.name),
        else => return null,
    };

    if (std.mem.eql(u8, name, "marquee") or std.mem.eql(u8, name, "blink")) return name;
    return null;
}
