const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "import/first";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    program: ast.Program,
) Allocator.Error!void {
    var past_import_section = false;

    for (tree.extra(program.body)) |statement_index| {
        switch (tree.data(statement_index)) {
            .import_declaration => {
                if (past_import_section) {
                    try core.addDiagnostic(
                        allocator,
                        diagnostics,
                        .@"error",
                        id,
                        "Import in body of module; reorder to top.",
                        tree.span(statement_index),
                    );
                }
            },
            .directive => {},
            else => past_import_section = true,
        }
    }
}
