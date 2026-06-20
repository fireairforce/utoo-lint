const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-implicit-globals";

pub const Options = struct {
    lexical_bindings: bool = false,
};

pub fn checkProgram(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    program: ast.Program,
    options: Options,
) Allocator.Error!void {
    if (program.source_type == .module) return;

    for (tree.extra(program.body)) |statement_index| {
        switch (tree.data(statement_index)) {
            .variable_declaration => |declaration| {
                if (declaration.kind == .@"var") {
                    try addImplicitGlobalDiagnostic(
                        allocator,
                        diagnostics,
                        tree,
                        statement_index,
                        "Implicit global variable declaration.",
                    );
                } else if (options.lexical_bindings) {
                    try addImplicitGlobalDiagnostic(
                        allocator,
                        diagnostics,
                        tree,
                        statement_index,
                        "Implicit global lexical declaration.",
                    );
                }
            },
            .function => |function| {
                if (function.type == .function_declaration) {
                    try addImplicitGlobalDiagnostic(
                        allocator,
                        diagnostics,
                        tree,
                        statement_index,
                        "Implicit global function declaration.",
                    );
                }
            },
            .class => |class| {
                if (options.lexical_bindings and class.type == .class_declaration) {
                    try addImplicitGlobalDiagnostic(
                        allocator,
                        diagnostics,
                        tree,
                        statement_index,
                        "Implicit global class declaration.",
                    );
                }
            },
            else => {},
        }
    }
}

fn addImplicitGlobalDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    message: []const u8,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        message,
        tree.span(index),
    );
}
