const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

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
        if (isIifeCall(ctx.tree, call) and !isAllowedStyle(ctx.tree, call, index, ctx.path.ancestor(1), self.style)) {
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

fn isAllowedStyle(tree: *const ast.Tree, call: ast.CallExpression, index: ast.NodeIndex, parent: ?ast.NodeIndex, style: Style) bool {
    return switch (style) {
        .outside => isParenthesized(tree, index, parent),
        .inside => tree.data(call.callee) == .parenthesized_expression,
        .any => isParenthesized(tree, index, parent) or tree.data(call.callee) == .parenthesized_expression,
    };
}

fn isIifeCall(tree: *const ast.Tree, call: ast.CallExpression) bool {
    return switch (tree.data(unwrapTransparent(tree, call.callee))) {
        .function => |function| function.type == .function_expression,
        else => false,
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
