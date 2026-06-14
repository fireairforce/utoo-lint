const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "consistent-return";

const ReturnKind = enum {
    value,
    bare,
};

const ScanState = struct {
    expected: ?ReturnKind = null,
    reported: bool = false,
};

pub fn checkFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
) Allocator.Error!void {
    if (function.body == .null) return;

    var state = ScanState{};
    try scanNode(allocator, diagnostics, tree, function.body, &state);
}

pub fn checkArrowFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ArrowFunctionExpression,
) Allocator.Error!void {
    if (expression.expression) return;

    var state = ScanState{};
    try scanNode(allocator, diagnostics, tree, expression.body, &state);
}

fn scanNode(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    state: *ScanState,
) Allocator.Error!void {
    if (index == .null or state.reported) return;

    switch (tree.data(index)) {
        .function,
        .arrow_function_expression,
        => return,
        .function_body => |body| try scanRange(allocator, diagnostics, tree, body.body, state),
        .block_statement => |block| try scanRange(allocator, diagnostics, tree, block.body, state),
        .return_statement => |statement| try checkReturn(allocator, diagnostics, tree, statement, index, state),
        .if_statement => |statement| {
            try scanNode(allocator, diagnostics, tree, statement.consequent, state);
            try scanNode(allocator, diagnostics, tree, statement.alternate, state);
        },
        .switch_statement => |statement| {
            for (tree.extra(statement.cases)) |case_index| {
                try scanNode(allocator, diagnostics, tree, case_index, state);
            }
        },
        .switch_case => |case| try scanRange(allocator, diagnostics, tree, case.consequent, state),
        .try_statement => |statement| {
            try scanNode(allocator, diagnostics, tree, statement.block, state);
            if (statement.handler != .null) {
                switch (tree.data(statement.handler)) {
                    .catch_clause => |handler| try scanNode(allocator, diagnostics, tree, handler.body, state),
                    else => {},
                }
            }
            try scanNode(allocator, diagnostics, tree, statement.finalizer, state);
        },
        .while_statement => |statement| try scanNode(allocator, diagnostics, tree, statement.body, state),
        .do_while_statement => |statement| try scanNode(allocator, diagnostics, tree, statement.body, state),
        .for_statement => |statement| try scanNode(allocator, diagnostics, tree, statement.body, state),
        .for_in_statement => |statement| try scanNode(allocator, diagnostics, tree, statement.body, state),
        .for_of_statement => |statement| try scanNode(allocator, diagnostics, tree, statement.body, state),
        .labeled_statement => |statement| try scanNode(allocator, diagnostics, tree, statement.body, state),
        .with_statement => |statement| try scanNode(allocator, diagnostics, tree, statement.body, state),
        else => {},
    }
}

fn scanRange(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    range: ast.IndexRange,
    state: *ScanState,
) Allocator.Error!void {
    for (tree.extra(range)) |statement| {
        try scanNode(allocator, diagnostics, tree, statement, state);
        if (state.reported) return;
    }
}

fn checkReturn(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ReturnStatement,
    index: ast.NodeIndex,
    state: *ScanState,
) Allocator.Error!void {
    const kind: ReturnKind = if (statement.argument == .null) .bare else .value;
    if (state.expected) |expected| {
        if (expected == kind) return;
        state.reported = true;
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            if (kind == .value) "Expected no return value." else "Expected a return value.",
            tree.span(index),
        );
        return;
    }
    state.expected = kind;
}
