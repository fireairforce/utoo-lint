const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "max-statements";

pub const Options = struct {
    max: usize = 10,
    ignore_top_level_functions: bool = false,
};

const FunctionKind = enum {
    function,
    arrow_function,
    static_block,

    fn label(self: FunctionKind) []const u8 {
        return switch (self) {
            .function => "Function",
            .arrow_function => "Arrow function",
            .static_block => "Static block",
        };
    }
};

const Frame = struct {
    index: ast.NodeIndex,
    count: usize = 0,
    kind: FunctionKind,
};

const PendingReport = struct {
    index: ast.NodeIndex,
    count: usize,
    kind: FunctionKind,
};

pub const State = struct {
    frames: std.ArrayList(Frame) = .empty,
    top_level_functions: std.ArrayList(PendingReport) = .empty,

    pub fn deinit(self: *State, allocator: Allocator) void {
        self.frames.deinit(allocator);
        self.top_level_functions.deinit(allocator);
    }
};

pub fn enterFunction(allocator: Allocator, state: *State, index: ast.NodeIndex) Allocator.Error!void {
    try state.frames.append(allocator, .{ .index = index, .kind = .function });
}

pub fn enterArrowFunction(allocator: Allocator, state: *State, index: ast.NodeIndex) Allocator.Error!void {
    try state.frames.append(allocator, .{ .index = index, .kind = .arrow_function });
}

pub fn enterStaticBlock(allocator: Allocator, state: *State, index: ast.NodeIndex) Allocator.Error!void {
    try state.frames.append(allocator, .{ .index = index, .kind = .static_block });
}

pub fn countFunctionBody(tree: *const ast.Tree, state: *State, body: ast.FunctionBody) void {
    _ = tree;
    countStatements(state, body.body.len);
}

pub fn countBlockStatement(tree: *const ast.Tree, state: *State, block: ast.BlockStatement) void {
    _ = tree;
    countStatements(state, block.body.len);
}

pub fn exitFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    state: *State,
    options: Options,
) Allocator.Error!void {
    const frame = state.frames.pop() orelse return;
    if (frame.kind == .static_block) return;

    if (options.ignore_top_level_functions and state.frames.items.len == 0) {
        try state.top_level_functions.append(allocator, .{
            .index = frame.index,
            .count = frame.count,
            .kind = frame.kind,
        });
        return;
    }

    try reportIfTooManyStatements(allocator, diagnostics, tree, frame.index, frame.kind, frame.count, options.max);
}

pub fn finishProgram(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    state: *State,
    options: Options,
) Allocator.Error!void {
    if (state.top_level_functions.items.len == 1) return;

    for (state.top_level_functions.items) |entry| {
        try reportIfTooManyStatements(allocator, diagnostics, tree, entry.index, entry.kind, entry.count, options.max);
    }
}

fn countStatements(state: *State, count: usize) void {
    if (state.frames.items.len == 0) return;
    state.frames.items[state.frames.items.len - 1].count += count;
}

fn reportIfTooManyStatements(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    kind: FunctionKind,
    count: usize,
    max: usize,
) Allocator.Error!void {
    if (count <= max) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "{s} has too many statements ({d}). Maximum allowed is {d}.",
        .{ kind.label(), count, max },
    );
}
