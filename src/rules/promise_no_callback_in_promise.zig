const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "promise/no-callback-in-promise";

pub const Options = struct {
    exceptions: core.PromiseNoCallbackInPromiseExceptions = .{},
    timeouts_err: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (isCallbackCall(tree, call, &options.exceptions)) {
        if (isInsidePromiseHandler(tree, ctx) and
            (options.timeouts_err or !isInsideTimeoutHandler(tree, ctx)))
        {
            try addDiagnostic(allocator, diagnostics, tree, index);
        }
        return;
    }

    const first_argument = firstArgument(tree, call);
    const first_argument_name = if (first_argument) |argument|
        identifierReferenceName(tree, argument)
    else
        null;

    if (isPromiseHandlerCall(tree, call)) {
        const name = first_argument_name orelse return;
        const calling_name = callCalleeName(tree, call.callee) orelse "";
        if (!options.exceptions.contains(name) and
            isCallbackName(name) and
            (options.timeouts_err or !isTimeoutName(calling_name)))
        {
            try addDiagnostic(allocator, diagnostics, tree, first_argument.?);
        }
        return;
    }

    if (!options.timeouts_err or first_argument_name == null) return;
    if (isInsidePromiseHandler(tree, ctx)) {
        try addDiagnostic(allocator, diagnostics, tree, index);
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
        "Avoid calling back inside of a promise.",
        tree.span(index),
    );
}

fn isCallbackCall(
    tree: *const ast.Tree,
    call: ast.CallExpression,
    exceptions: *const core.PromiseNoCallbackInPromiseExceptions,
) bool {
    const name = identifierReferenceName(tree, call.callee) orelse return false;
    return isCallbackName(name) and !exceptions.contains(name);
}

fn isCallbackName(name: []const u8) bool {
    const callback_names = [_][]const u8{ "callback", "cb", "next", "done" };
    for (callback_names) |callback_name| {
        if (std.mem.eql(u8, name, callback_name)) return true;
    }
    return false;
}

fn isInsidePromiseHandler(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .function,
            .arrow_function_expression,
            => {
                const parent = ctx.path.ancestor(depth + 1) orelse continue;
                const call = switch (tree.data(parent)) {
                    .call_expression => |call| call,
                    else => continue,
                };
                if (isPromiseHandlerCall(tree, call)) return true;
            },
            else => {},
        }
    }
    return false;
}

fn isInsideTimeoutHandler(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .function,
            .arrow_function_expression,
            => {
                const parent = ctx.path.ancestor(depth + 1) orelse continue;
                const call = switch (tree.data(parent)) {
                    .call_expression => |call| call,
                    else => continue,
                };
                const name = callCalleeName(tree, call.callee) orelse continue;
                if (isTimeoutName(name)) return true;
            },
            else => {},
        }
    }
    return false;
}

fn isPromiseHandlerCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    const name = callCalleeName(tree, call.callee) orelse return false;
    return std.mem.eql(u8, name, "then") or std.mem.eql(u8, name, "catch");
}

fn isTimeoutName(name: []const u8) bool {
    const timeout_names = [_][]const u8{
        "setImmediate",
        "setTimeout",
        "requestAnimationFrame",
        "nextTick",
    };
    for (timeout_names) |timeout_name| {
        if (std.mem.eql(u8, name, timeout_name)) return true;
    }
    return false;
}

fn callCalleeName(tree: *const ast.Tree, callee_index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, callee_index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .member_expression => |member| memberPropertyName(tree, member),
        else => null,
    };
}

fn memberPropertyName(tree: *const ast.Tree, member: ast.MemberExpression) ?[]const u8 {
    if (member.property == .null) return null;
    return switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn firstArgument(tree: *const ast.Tree, call: ast.CallExpression) ?ast.NodeIndex {
    const arguments = tree.extra(call.arguments);
    if (arguments.len == 0) return null;
    return arguments[0];
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;
    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |chain| current = chain.expression,
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            else => return current,
        }
    }
    return current;
}
