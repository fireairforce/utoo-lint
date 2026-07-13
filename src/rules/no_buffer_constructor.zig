const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-buffer-constructor";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    _: traverser.semantic.SymbolTable,
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

    pub fn enter_new_expression(
        self: *Visitor,
        expression: ast.NewExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (isBufferConstructorCallee(ctx.tree, expression.callee)) {
            try self.addDiagnostic(ctx.tree, index);
        }

        return .proceed;
    }

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (isBufferConstructorCallee(ctx.tree, call.callee)) {
            try self.addDiagnostic(ctx.tree, index);
        }

        return .proceed;
    }

    fn addDiagnostic(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            "Do not use the Buffer constructor.",
            tree.span(index),
        );
    }
};

fn isBufferConstructorCallee(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const unwrapped = unwrapTransparent(tree, index);
    const name = identifierReferenceName(tree, unwrapped) orelse return false;

    return std.mem.eql(u8, name, "Buffer");
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
