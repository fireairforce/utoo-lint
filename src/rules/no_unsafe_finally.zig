const parser = @import("parser");
const core = @import("../core.zig");
const std = @import("std");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-unsafe-finally";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.TryStatement,
) Allocator.Error!void {
    if (statement.finalizer == .null) return;

    try scanNode(allocator, diagnostics, tree, statement.finalizer);
}

const ScanState = struct {
    break_boundaries: usize = 0,
    continue_boundaries: usize = 0,
    labels: [64][]const u8 = undefined,
    label_count: usize = 0,

    fn withBreakBoundary(self: ScanState) ScanState {
        var next = self;
        next.break_boundaries += 1;
        return next;
    }

    fn withLoopBoundary(self: ScanState) ScanState {
        var next = self;
        next.break_boundaries += 1;
        next.continue_boundaries += 1;
        return next;
    }

    fn withLabel(self: ScanState, label: []const u8) ScanState {
        var next = self;
        if (next.label_count < next.labels.len) {
            next.labels[next.label_count] = label;
            next.label_count += 1;
        }
        return next;
    }

    fn containsLabel(self: ScanState, label: []const u8) bool {
        for (self.labels[0..self.label_count]) |current| {
            if (std.mem.eql(u8, current, label)) return true;
        }
        return false;
    }
};

fn scanNode(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    return scanNodeWithState(allocator, diagnostics, tree, index, .{});
}

fn scanNodeWithState(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    state: ScanState,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(index)) {
        .return_statement,
        .throw_statement,
        => try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Control flow statements in finally blocks are unsafe.",
            tree.span(index),
        ),
        .break_statement => |statement| {
            if (breakIsLocal(tree, statement, state)) return;
            try addDiagnostic(allocator, diagnostics, tree, index);
        },
        .continue_statement => |statement| {
            if (continueIsLocal(tree, statement, state)) return;
            try addDiagnostic(allocator, diagnostics, tree, index);
        },
        .block_statement => |block| try scanRange(allocator, diagnostics, tree, block.body, state),
        .static_block => |block| try scanRange(allocator, diagnostics, tree, block.body, state),
        .if_statement => |statement| {
            try scanNodeWithState(allocator, diagnostics, tree, statement.consequent, state);
            try scanNodeWithState(allocator, diagnostics, tree, statement.alternate, state);
        },
        .switch_statement => |statement| {
            const switch_state = state.withBreakBoundary();
            for (tree.extra(statement.cases)) |case_index| {
                const switch_case = switch (tree.data(case_index)) {
                    .switch_case => |switch_case| switch_case,
                    else => continue,
                };
                try scanRange(allocator, diagnostics, tree, switch_case.consequent, switch_state);
            }
        },
        .for_statement => |statement| try scanNodeWithState(allocator, diagnostics, tree, statement.body, state.withLoopBoundary()),
        .for_in_statement => |statement| try scanNodeWithState(allocator, diagnostics, tree, statement.body, state.withLoopBoundary()),
        .for_of_statement => |statement| try scanNodeWithState(allocator, diagnostics, tree, statement.body, state.withLoopBoundary()),
        .while_statement => |statement| try scanNodeWithState(allocator, diagnostics, tree, statement.body, state.withLoopBoundary()),
        .do_while_statement => |statement| try scanNodeWithState(allocator, diagnostics, tree, statement.body, state.withLoopBoundary()),
        .with_statement => |statement| try scanNodeWithState(allocator, diagnostics, tree, statement.body, state),
        .labeled_statement => |statement| {
            const next_state = if (labelName(tree, statement.label)) |label|
                state.withLabel(label)
            else
                state;
            try scanNodeWithState(allocator, diagnostics, tree, statement.body, next_state);
        },
        .try_statement => |statement| {
            try scanNodeWithState(allocator, diagnostics, tree, statement.block, state);
            if (statement.handler != .null) {
                const handler = switch (tree.data(statement.handler)) {
                    .catch_clause => |handler| handler,
                    else => return,
                };
                try scanNodeWithState(allocator, diagnostics, tree, handler.body, state);
            }
        },
        .function,
        .class,
        => return,
        else => return,
    }
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
        "Control flow statements in finally blocks are unsafe.",
        tree.span(index),
    );
}

fn breakIsLocal(tree: *const ast.Tree, statement: ast.BreakStatement, state: ScanState) bool {
    if (labelName(tree, statement.label)) |label| return state.containsLabel(label);
    return state.break_boundaries > 0;
}

fn continueIsLocal(tree: *const ast.Tree, statement: ast.ContinueStatement, state: ScanState) bool {
    if (labelName(tree, statement.label)) |label| return state.containsLabel(label);
    return state.continue_boundaries > 0;
}

fn labelName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .label_identifier => |label| tree.string(label.name),
        else => null,
    };
}

fn scanRange(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    range: ast.IndexRange,
    state: ScanState,
) Allocator.Error!void {
    for (tree.extra(range)) |child| {
        try scanNodeWithState(allocator, diagnostics, tree, child, state);
    }
}
