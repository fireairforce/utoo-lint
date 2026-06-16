const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-regex-spaces";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    var visitor = Visitor{
        .allocator = allocator,
        .diagnostics = diagnostics,
        .symbol_table = symbol_table,
    };

    try traverser.basic.traverse(Visitor, tree, &visitor);
}

const Visitor = struct {
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    symbol_table: traverser.semantic.SymbolTable,

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.checkConstructor(ctx.tree, call.callee, call.arguments, index);
        return .proceed;
    }

    pub fn enter_new_expression(
        self: *Visitor,
        expression: ast.NewExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.checkConstructor(ctx.tree, expression.callee, expression.arguments, index);
        return .proceed;
    }

    fn checkConstructor(
        self: *Visitor,
        tree: *const ast.Tree,
        callee: ast.NodeIndex,
        argument_range: ast.IndexRange,
        index: ast.NodeIndex,
    ) Allocator.Error!void {
        const arguments = tree.extra(argument_range);
        if (arguments.len == 0) return;
        if (!isGlobalRegExpReference(tree, self.symbol_table, callee)) return;

        const pattern = stringLiteralValue(tree, arguments[0]) orelse return;
        if (!hasConsecutiveSpaces(pattern)) return;

        try addDiagnostic(self.allocator, self.diagnostics, tree, index);
    }
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.RegExpLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (!hasConsecutiveSpaces(tree.string(literal.pattern))) return;

    try addDiagnostic(allocator, diagnostics, tree, index);
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
        "Avoid multiple spaces in regular expression literals.",
        tree.span(index),
    );
}

fn isGlobalRegExpReference(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    index: ast.NodeIndex,
) bool {
    const unwrapped = unwrapTransparent(tree, index);
    const name = identifierReferenceName(tree, unwrapped) orelse return false;
    return std.mem.eql(u8, name, "RegExp") and isUnresolvedReference(symbol_table, unwrapped);
}

fn stringLiteralValue(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .string_literal => |literal| tree.string(literal.value),
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

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isUnresolvedReference(
    symbol_table: traverser.semantic.SymbolTable,
    node: ast.NodeIndex,
) bool {
    var iter = symbol_table.iterReferences();
    while (iter.next()) |entry| {
        if (entry.reference.node == node) {
            return symbol_table.referenceSymbol(entry.id) == .none;
        }
    }

    return false;
}

fn hasConsecutiveSpaces(pattern: []const u8) bool {
    var in_class = false;
    var escaped = false;
    var previous_space = false;

    for (pattern) |char| {
        if (escaped) {
            escaped = false;
            previous_space = false;
            continue;
        }

        switch (char) {
            '\\' => {
                escaped = true;
                previous_space = false;
            },
            '[' => {
                in_class = true;
                previous_space = false;
            },
            ']' => {
                in_class = false;
                previous_space = false;
            },
            ' ' => {
                if (!in_class and previous_space) return true;
                previous_space = !in_class;
            },
            else => previous_space = false,
        }
    }

    return false;
}
