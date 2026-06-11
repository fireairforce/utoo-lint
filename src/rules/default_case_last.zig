const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "default-case-last";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.SwitchStatement,
) Allocator.Error!void {
    var default_case: ast.NodeIndex = .null;

    for (tree.extra(statement.cases)) |case_index| {
        const switch_case = switch (tree.data(case_index)) {
            .switch_case => |switch_case| switch_case,
            else => continue,
        };

        if (switch_case.@"test" == .null) {
            default_case = case_index;
        } else if (default_case != .null) {
            try core.addDiagnostic(
                allocator,
                diagnostics,
                .warning,
                id,
                "Default case should be the last case.",
                tree.span(default_case),
            );
            return;
        }
    }
}
