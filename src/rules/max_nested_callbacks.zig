const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "max-nested-callbacks";

pub const Options = struct {
    max: usize = 10,
};

pub const State = struct {
    callbacks: std.ArrayList(ast.NodeIndex) = .empty,

    pub fn deinit(self: *State, allocator: Allocator) void {
        self.callbacks.deinit(allocator);
    }
};

pub fn enterFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
    path: *const traverser.NodePath,
    state: *State,
    options: Options,
) Allocator.Error!void {
    if (function.type != .function_expression) return;
    try enterCallback(allocator, diagnostics, tree, index, path, state, options);
}

pub fn enterArrowFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    path: *const traverser.NodePath,
    state: *State,
    options: Options,
) Allocator.Error!void {
    try enterCallback(allocator, diagnostics, tree, index, path, state, options);
}

pub fn exitFunction(state: *State, index: ast.NodeIndex) void {
    if (state.callbacks.items.len > 0 and state.callbacks.items[state.callbacks.items.len - 1] == index) {
        _ = state.callbacks.pop();
    }
}

fn enterCallback(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    path: *const traverser.NodePath,
    state: *State,
    options: Options,
) Allocator.Error!void {
    if (!isCallArgument(tree, index, path.parent())) return;

    try state.callbacks.append(allocator, index);
    const depth = state.callbacks.items.len;
    if (depth <= options.max) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Too many nested callbacks ({d}). Maximum allowed is {d}.",
        .{ depth, options.max },
    );
}

fn isCallArgument(tree: *const ast.Tree, index: ast.NodeIndex, parent_index: ?ast.NodeIndex) bool {
    const parent = parent_index orelse return false;
    const call = switch (tree.data(parent)) {
        .call_expression => |call| call,
        else => return false,
    };
    return call.callee != index;
}
