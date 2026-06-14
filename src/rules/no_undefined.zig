const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-undefined";

pub fn checkIdentifierReference(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    identifier: ast.IdentifierReference,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const name = tree.string(identifier.name);
    if (!std.mem.eql(u8, name, "undefined")) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected use of undefined.",
        tree.span(index),
    );
}

pub fn checkBindingIdentifier(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    identifier: ast.BindingIdentifier,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const name = tree.string(identifier.name);
    if (!std.mem.eql(u8, name, "undefined")) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected use of undefined.",
        tree.span(index),
    );
}
