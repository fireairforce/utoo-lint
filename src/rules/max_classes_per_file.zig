const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "max-classes-per-file";

pub const Options = struct {
    max: usize = 1,
    ignore_expressions: bool = false,
};

pub const State = struct {
    class_count: usize = 0,
};

pub fn enterProgram(state: *State) void {
    state.class_count = 0;
}

pub fn checkClass(class: ast.Class, state: *State, options: Options) void {
    switch (class.type) {
        .class_declaration => state.class_count += 1,
        .class_expression => if (!options.ignore_expressions) {
            state.class_count += 1;
        },
    }
}

pub fn exitProgram(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    state: State,
    options: Options,
) Allocator.Error!void {
    if (state.class_count <= options.max) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "File has too many classes ({d}). Maximum allowed is {d}.",
        .{ state.class_count, options.max },
    );
}
