const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-empty-interface";

pub const Options = struct {
    allow_single_extends: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    interface_declaration: ast.TSInterfaceDeclaration,
    options: Options,
) Allocator.Error!void {
    const body = switch (tree.data(interface_declaration.body)) {
        .ts_interface_body => |interface_body| interface_body,
        else => return,
    };

    if (body.body.len != 0) return;

    const message =
        if (interface_declaration.extends.len == 0)
            "An empty interface is equivalent to `{}`."
        else if (interface_declaration.extends.len == 1 and !options.allow_single_extends)
            "An interface declaring no members is equivalent to its supertype."
        else
            return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        message,
        tree.span(interface_declaration.id),
    );
}
