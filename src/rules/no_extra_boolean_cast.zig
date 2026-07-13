const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-extra-boolean-cast";

pub const Options = struct {
    enforce_for_inner_expressions: bool = false,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    _: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    try runWithOptions(allocator, diagnostics, tree, .{});
}

pub fn runWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    options: Options,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .options = options,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    options: Options,

    pub fn enter_if_statement(
        self: *Visitor,
        statement: ast.IfStatement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.checkBooleanContext(ctx.tree, statement.@"test");
        return .proceed;
    }

    pub fn enter_while_statement(
        self: *Visitor,
        statement: ast.WhileStatement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.checkBooleanContext(ctx.tree, statement.@"test");
        return .proceed;
    }

    pub fn enter_do_while_statement(
        self: *Visitor,
        statement: ast.DoWhileStatement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.checkBooleanContext(ctx.tree, statement.@"test");
        return .proceed;
    }

    pub fn enter_for_statement(
        self: *Visitor,
        statement: ast.ForStatement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (statement.@"test" != .null) {
            try self.checkBooleanContext(ctx.tree, statement.@"test");
        }
        return .proceed;
    }

    pub fn enter_conditional_expression(
        self: *Visitor,
        expression: ast.ConditionalExpression,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.checkBooleanContext(ctx.tree, expression.@"test");
        return .proceed;
    }

    fn checkBooleanContext(
        self: *Visitor,
        tree: *const ast.Tree,
        expression: ast.NodeIndex,
    ) Allocator.Error!void {
        const unwrapped = unwrapTransparent(tree, expression);
        try self.checkBooleanExpression(tree, unwrapped);
    }

    fn checkBooleanExpression(
        self: *Visitor,
        tree: *const ast.Tree,
        unwrapped: ast.NodeIndex,
    ) Allocator.Error!void {
        if (isBooleanCall(tree, unwrapped) or isDoubleNegation(tree, unwrapped)) {
            try core.addDiagnostic(
                self.allocator,
                self.diagnostics,
                .warning,
                id,
                "Redundant boolean cast in a boolean context.",
                tree.span(unwrapped),
            );
        }

        switch (tree.data(unwrapped)) {
            .unary_expression => |unary| {
                if (unary.operator != .logical_not) return;
                try self.checkBooleanExpression(tree, unwrapTransparent(tree, unary.argument));
            },
            .logical_expression => |logical| {
                if (!self.options.enforce_for_inner_expressions) return;
                try self.checkBooleanExpression(tree, unwrapTransparent(tree, logical.left));
                try self.checkBooleanExpression(tree, unwrapTransparent(tree, logical.right));
            },
            else => return,
        }
    }
};

fn isBooleanCall(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const call = switch (tree.data(index)) {
        .call_expression => |call| call,
        else => return false,
    };

    const callee = unwrapTransparent(tree, call.callee);
    const name = identifierReferenceName(tree, callee) orelse return false;
    return std.mem.eql(u8, name, "Boolean");
}

fn isDoubleNegation(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const outer = switch (tree.data(index)) {
        .unary_expression => |unary| unary,
        else => return false,
    };
    if (outer.operator != .logical_not) return false;

    const inner_index = unwrapTransparent(tree, outer.argument);
    const inner = switch (tree.data(inner_index)) {
        .unary_expression => |unary| unary,
        else => return false,
    };
    return inner.operator == .logical_not;
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

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}
