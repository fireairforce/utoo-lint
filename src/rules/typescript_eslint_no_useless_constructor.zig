const parser = @import("parser");
const core = @import("../core.zig");
const no_useless_constructor = @import("no_useless_constructor.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-useless-constructor";

pub fn checkClass(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    class: ast.Class,
) Allocator.Error!void {
    const body = switch (tree.data(class.body)) {
        .class_body => |body| body,
        else => return,
    };

    for (tree.extra(body.body)) |member_index| {
        const method = switch (tree.data(member_index)) {
            .method_definition => |method| method,
            else => continue,
        };
        if (!no_useless_constructor.isUselessConstructor(tree, class, method)) continue;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .@"error",
            id,
            "Useless constructor.",
            tree.span(member_index),
        );
    }
}
