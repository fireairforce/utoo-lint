const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "wrap-iife";

pub const Style = enum {
    outside,
    inside,
    any,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    try runWithStyle(allocator, diagnostics, tree, .outside);
}

pub fn runWithStyle(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    style: Style,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .style = style,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    style: Style,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        const function_index = iifeFunctionIndex(ctx.tree, call) orelse return .proceed;
        const parent = ctx.path.ancestor(1);
        if (!isAllowedStyle(ctx.tree, call, index, parent, self.style)) {
            if (try buildFix(self.allocator, ctx.tree, call, index, function_index, parent, self.style)) |fix| {
                defer self.allocator.free(fix.replacement);
                try core.addDiagnosticWithFix(
                    self.allocator,
                    self.diagnostics,
                    .warning,
                    id,
                    "Wrap an immediate function invocation in parentheses.",
                    ctx.tree.span(index),
                    fix,
                );
                return .proceed;
            }

            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                "Wrap an immediate function invocation in parentheses.",
                ctx.tree.span(index),
            );
        }

        return .proceed;
    }
};

fn buildFix(
    allocator: Allocator,
    tree: *const ast.Tree,
    call: ast.CallExpression,
    index: ast.NodeIndex,
    function_index: ast.NodeIndex,
    parent: ?ast.NodeIndex,
    style: Style,
) Allocator.Error!?core.Fix {
    const call_is_parenthesized = isParenthesized(tree, index, parent);
    const function_is_parenthesized = tree.data(call.callee) == .parenthesized_expression;

    if (!call_is_parenthesized and !function_is_parenthesized) {
        const span = if (style == .inside) tree.span(function_index) else tree.span(index);
        return .{
            .span = span,
            .replacement = try std.fmt.allocPrint(allocator, "({s})", .{tree.source[span.start..span.end]}),
        };
    }

    if (style == .outside and function_is_parenthesized) {
        const callee_span = tree.span(call.callee);
        const call_span = tree.span(index);
        if (callee_span.end == 0 or tree.source[callee_span.end - 1] != ')') return null;
        return .{
            .span = .{ .start = callee_span.end - 1, .end = call_span.end },
            .replacement = try std.fmt.allocPrint(
                allocator,
                "{s})",
                .{tree.source[callee_span.end..call_span.end]},
            ),
        };
    }

    if (style == .inside and call_is_parenthesized) {
        const parent_index = parent orelse return null;
        const parent_span = tree.span(parent_index);
        const function_span = tree.span(function_index);
        if (parent_span.end == 0 or tree.source[parent_span.end - 1] != ')') return null;
        return .{
            .span = .{ .start = function_span.end, .end = parent_span.end },
            .replacement = try std.fmt.allocPrint(
                allocator,
                "){s}",
                .{tree.source[function_span.end .. parent_span.end - 1]},
            ),
        };
    }

    return null;
}

fn isAllowedStyle(tree: *const ast.Tree, call: ast.CallExpression, index: ast.NodeIndex, parent: ?ast.NodeIndex, style: Style) bool {
    return switch (style) {
        .outside => isParenthesized(tree, index, parent),
        .inside => tree.data(call.callee) == .parenthesized_expression,
        .any => isParenthesized(tree, index, parent) or tree.data(call.callee) == .parenthesized_expression,
    };
}

fn iifeFunctionIndex(tree: *const ast.Tree, call: ast.CallExpression) ?ast.NodeIndex {
    const index = unwrapTransparent(tree, call.callee);
    return switch (tree.data(index)) {
        .function => |function| if (function.type == .function_expression) index else null,
        else => null,
    };
}

fn isParenthesized(tree: *const ast.Tree, index: ast.NodeIndex, parent: ?ast.NodeIndex) bool {
    const parent_index = parent orelse return false;
    return switch (tree.data(parent_index)) {
        .parenthesized_expression => |parenthesized| parenthesized.expression == index,
        else => false,
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
