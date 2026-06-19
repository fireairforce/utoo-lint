const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "complexity";

pub const Variant = enum {
    classic,
    modified,
};

pub const Options = struct {
    max: usize = 20,
    variant: Variant = .classic,
};

const FunctionKind = enum {
    function,
    arrow_function,
    static_block,

    fn label(self: FunctionKind) []const u8 {
        return switch (self) {
            .function => "Function",
            .arrow_function => "Arrow function",
            .static_block => "Class static block",
        };
    }
};

const Frame = struct {
    index: ast.NodeIndex,
    complexity: usize = 1,
    kind: FunctionKind,
};

pub const State = struct {
    frames: std.ArrayList(Frame) = .empty,

    pub fn deinit(self: *State, allocator: Allocator) void {
        self.frames.deinit(allocator);
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

pub fn exitFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    state: *State,
    options: Options,
) Allocator.Error!void {
    const frame = state.frames.pop() orelse return;
    if (frame.complexity <= options.max) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(frame.index),
        "{s} has a complexity of {d}. Maximum allowed is {d}.",
        .{ frame.kind.label(), frame.complexity, options.max },
    );
}

pub fn increase(state: *State) void {
    if (state.frames.items.len == 0) return;
    state.frames.items[state.frames.items.len - 1].complexity += 1;
}

pub fn countSwitchStatement(state: *State, options: Options) void {
    if (options.variant == .modified) increase(state);
}

pub fn countSwitchCase(state: *State, switch_case: ast.SwitchCase, options: Options) void {
    if (options.variant == .classic and switch_case.@"test" != .null) increase(state);
}

pub fn countAssignmentExpression(state: *State, expression: ast.AssignmentExpression) void {
    switch (expression.operator) {
        .logical_or_assign,
        .logical_and_assign,
        .nullish_assign,
        => increase(state),
        else => {},
    }
}

pub fn countCallExpression(state: *State, call: ast.CallExpression) void {
    if (call.optional) increase(state);
}

pub fn countMemberExpression(state: *State, member: ast.MemberExpression) void {
    if (member.optional) increase(state);
}
