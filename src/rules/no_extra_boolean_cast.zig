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
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    try runWithOptions(allocator, diagnostics, tree, symbol_table, .{});
}

pub fn runWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    options: Options,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
        .options = options,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,
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
        try self.checkBooleanExpression(tree, unwrapped, .direct);
    }

    fn checkBooleanExpression(
        self: *Visitor,
        tree: *const ast.Tree,
        unwrapped: ast.NodeIndex,
        context: BooleanContext,
    ) Allocator.Error!void {
        if (booleanCall(tree, unwrapped)) |call| {
            try self.addBooleanCallDiagnostic(tree, unwrapped, call, context);
        } else if (doubleNegationValue(tree, unwrapped)) |value| {
            try self.addDoubleNegationDiagnostic(tree, unwrapped, value, context);
        }

        switch (tree.data(unwrapped)) {
            .unary_expression => |unary| {
                if (unary.operator != .logical_not) return;
                try self.checkBooleanExpression(tree, unwrapTransparent(tree, unary.argument), .{ .unary = unwrapped });
            },
            .logical_expression => |logical| {
                if (!self.options.enforce_for_inner_expressions) return;
                try self.checkBooleanExpression(tree, unwrapTransparent(tree, logical.left), .logical);
                try self.checkBooleanExpression(tree, unwrapTransparent(tree, logical.right), .logical);
            },
            else => return,
        }
    }

    fn addBooleanCallDiagnostic(
        self: *Visitor,
        tree: *const ast.Tree,
        index: ast.NodeIndex,
        call: ast.CallExpression,
        context: BooleanContext,
    ) Allocator.Error!void {
        if (!isGlobalBooleanReference(tree, self.symbol_table, call.callee) or
            call.optional or
            hasCommentsInside(tree, tree.span(index)))
        {
            try self.addDiagnostic(tree, index);
            return;
        }

        const arguments = tree.extra(call.arguments);
        if (arguments.len == 0) {
            switch (context) {
                .unary => |parent| {
                    if (hasCommentsInside(tree, tree.span(parent))) {
                        try self.addDiagnostic(tree, index);
                        return;
                    }
                    try self.addDiagnosticWithFix(tree, index, tree.span(parent), "true");
                },
                else => try self.addDiagnosticWithFix(tree, index, tree.span(index), "false"),
            }
            return;
        }

        if (arguments.len != 1 or tree.data(arguments[0]) == .spread_element) {
            try self.addDiagnostic(tree, index);
            return;
        }

        try self.addReplacementNodeFix(tree, index, tree.span(index), arguments[0], context);
    }

    fn addDoubleNegationDiagnostic(
        self: *Visitor,
        tree: *const ast.Tree,
        index: ast.NodeIndex,
        value: ast.NodeIndex,
        context: BooleanContext,
    ) Allocator.Error!void {
        if (hasCommentsInside(tree, tree.span(index))) {
            try self.addDiagnostic(tree, index);
            return;
        }

        try self.addReplacementNodeFix(tree, index, tree.span(index), value, context);
    }

    fn addReplacementNodeFix(
        self: *Visitor,
        tree: *const ast.Tree,
        diagnostic_index: ast.NodeIndex,
        fix_span: ast.Span,
        replacement_index: ast.NodeIndex,
        context: BooleanContext,
    ) Allocator.Error!void {
        const replacement_span = tree.span(replacement_index);
        const source = tree.source[replacement_span.start..replacement_span.end];
        if (!replacementNeedsParentheses(tree, replacement_index, context)) {
            try self.addDiagnosticWithFix(tree, diagnostic_index, fix_span, source);
            return;
        }

        const replacement = try std.fmt.allocPrint(self.allocator, "({s})", .{source});
        defer self.allocator.free(replacement);
        try self.addDiagnosticWithFix(tree, diagnostic_index, fix_span, replacement);
    }

    fn addDiagnostic(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            "Redundant boolean cast in a boolean context.",
            tree.span(index),
        );
    }

    fn addDiagnosticWithFix(
        self: *Visitor,
        tree: *const ast.Tree,
        diagnostic_index: ast.NodeIndex,
        fix_span: ast.Span,
        replacement: []const u8,
    ) Allocator.Error!void {
        try core.addDiagnosticWithFix(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            "Redundant boolean cast in a boolean context.",
            tree.span(diagnostic_index),
            .{ .span = fix_span, .replacement = replacement },
        );
    }
};

const BooleanContext = union(enum) {
    direct,
    unary: ast.NodeIndex,
    logical,
};

fn booleanCall(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.CallExpression {
    const call = switch (tree.data(index)) {
        .call_expression => |call| call,
        else => return null,
    };
    const callee = unwrapTransparent(tree, call.callee);
    const name = identifierReferenceName(tree, callee) orelse return null;
    if (!std.mem.eql(u8, name, "Boolean")) return null;
    return call;
}

fn isGlobalBooleanReference(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    callee_index: ast.NodeIndex,
) bool {
    const callee = unwrapTransparent(tree, callee_index);
    const name = identifierReferenceName(tree, callee) orelse return false;
    return std.mem.eql(u8, name, "Boolean") and isUnresolvedReference(symbol_table, callee);
}

fn doubleNegationValue(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.NodeIndex {
    const outer = switch (tree.data(index)) {
        .unary_expression => |unary| unary,
        else => return null,
    };
    if (outer.operator != .logical_not) return null;

    const inner_index = unwrapTransparent(tree, outer.argument);
    const inner = switch (tree.data(inner_index)) {
        .unary_expression => |unary| unary,
        else => return null,
    };
    if (inner.operator != .logical_not) return null;
    return inner.argument;
}

fn hasCommentsInside(tree: *const ast.Tree, span: ast.Span) bool {
    for (tree.comments) |comment| {
        if (comment.span.start >= span.start and comment.span.end <= span.end) return true;
    }
    return false;
}

fn replacementNeedsParentheses(tree: *const ast.Tree, index: ast.NodeIndex, context: BooleanContext) bool {
    if (tree.data(index) == .parenthesized_expression) return false;

    return switch (context) {
        .direct => false,
        .unary => hasLowerThanUnaryPrecedence(tree, index),
        .logical => hasLogicalOrLowerPrecedence(tree, index),
    };
}

fn hasLowerThanUnaryPrecedence(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .binary_expression,
        .logical_expression,
        .conditional_expression,
        .assignment_expression,
        .sequence_expression,
        .arrow_function_expression,
        .yield_expression,
        .ts_as_expression,
        .ts_satisfies_expression,
        => true,
        else => false,
    };
}

fn hasLogicalOrLowerPrecedence(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .logical_expression,
        .conditional_expression,
        .assignment_expression,
        .sequence_expression,
        .arrow_function_expression,
        .yield_expression,
        .ts_as_expression,
        .ts_satisfies_expression,
        => true,
        else => false,
    };
}

fn isUnresolvedReference(symbol_table: traverser.semantic.SymbolTable, node: ast.NodeIndex) bool {
    var iter = symbol_table.iterReferences();
    while (iter.next()) |entry| {
        if (entry.reference.node == node) return symbol_table.referenceSymbol(entry.id) == .none;
    }
    return false;
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
