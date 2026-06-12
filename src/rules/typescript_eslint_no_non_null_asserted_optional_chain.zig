const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/no-non-null-asserted-optional-chain";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,

    pub fn enter_ts_non_null_expression(
        self: *Visitor,
        expression: ast.TSNonNullExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (isChainExpression(ctx.tree, expression.expression)) {
            try self.addDiagnostic(ctx.tree, index);
        }

        return .proceed;
    }

    pub fn enter_chain_expression(
        self: *Visitor,
        expression: ast.ChainExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (isNonNullExpression(ctx.tree, expression.expression)) {
            try self.addDiagnostic(ctx.tree, expression.expression);
        }

        return .proceed;
    }

    fn addDiagnostic(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .@"error",
            id,
            "Optional chain expressions can return undefined by design - using a non-null assertion is unsafe and wrong.",
            tree.span(index),
        );
    }
};

fn isChainExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const unwrapped = unwrapParenthesized(tree, index);
    if (unwrapped == .null) return false;
    return switch (tree.data(unwrapped)) {
        .chain_expression => true,
        else => false,
    };
}

fn isNonNullExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .ts_non_null_expression => true,
        else => false,
    };
}

fn unwrapParenthesized(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;

    while (current != .null) {
        switch (tree.data(current)) {
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            else => return current,
        }
    }

    return current;
}
