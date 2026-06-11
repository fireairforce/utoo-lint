const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-case-declarations";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    switch_case: ast.SwitchCase,
) Allocator.Error!void {
    for (tree.extra(switch_case.consequent)) |statement_index| {
        if (!isLexicalDeclaration(tree, statement_index)) continue;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Wrap lexical declarations in a block statement.",
            tree.span(statement_index),
        );
    }
}

fn isLexicalDeclaration(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .variable_declaration => |declaration| declaration.kind != .@"var",
        .function => |function| function.type == .function_declaration or function.type == .ts_declare_function,
        .class => |class| class.type == .class_declaration,
        else => false,
    };
}
