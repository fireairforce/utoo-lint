const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-script-url";

pub fn checkStringLiteral(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.StringLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!isScriptUrl(tree.string(literal.value))) return;
    try addDiagnostic(allocator, diagnostics, tree, index);
}

pub fn checkTemplateLiteral(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.TemplateLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (literal.expressions.len != 0) return;
    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return;

    const quasi = tree.data(quasis[0]).template_element;
    if (quasi.is_cooked_undefined) return;
    if (!isScriptUrl(tree.string(quasi.cooked))) return;
    try addDiagnostic(allocator, diagnostics, tree, index);
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Script URL is a form of eval.",
        tree.span(index),
    );
}

fn isScriptUrl(value: []const u8) bool {
    return startsWithIgnoreAsciiCase(value, "javascript:");
}

fn startsWithIgnoreAsciiCase(value: []const u8, prefix: []const u8) bool {
    if (value.len < prefix.len) return false;

    for (prefix, 0..) |expected, index| {
        if (std.ascii.toLower(value[index]) != expected) return false;
    }
    return true;
}
