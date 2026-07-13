const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
const Allocator = std.mem.Allocator;

pub const id = "radix";

pub const Style = enum {
    always,
    as_needed,
};

pub const Options = struct {
    style: Style = .always,
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

    pub fn enter_call_expression(
        self: *Visitor,
        call: ast.CallExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (isGlobalParseIntCall(ctx.tree, self.symbol_table, call.callee)) {
            try self.checkArguments(ctx.tree, call, index);
        }

        return .proceed;
    }

    fn checkArguments(
        self: *Visitor,
        tree: *const ast.Tree,
        call: ast.CallExpression,
        index: ast.NodeIndex,
    ) Allocator.Error!void {
        const arguments = tree.extra(call.arguments);
        if (arguments.len == 0) {
            try self.addDiagnostic(tree, index, "Missing parameters.");
            return;
        }

        if (arguments.len == 1) {
            if (self.options.style == .always) {
                try self.addDiagnostic(tree, index, "Missing radix parameter.");
            }
            return;
        }

        if (!isValidRadix(tree, arguments[1])) {
            try self.addDiagnostic(tree, index, "Invalid radix parameter, must be an integer between 2 and 36.");
            return;
        }

        if (self.options.style == .as_needed and isDecimalRadix(tree, arguments[1])) {
            try self.addDiagnostic(tree, index, "Redundant radix parameter.");
        }
    }

    fn addDiagnostic(
        self: *Visitor,
        tree: *const ast.Tree,
        index: ast.NodeIndex,
        message: []const u8,
    ) Allocator.Error!void {
        try core.addDiagnostic(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            message,
            tree.span(index),
        );
    }
};

fn isGlobalParseIntCall(
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    callee: ast.NodeIndex,
) bool {
    const unwrapped = unwrapTransparent(tree, callee);

    if (identifierReferenceName(tree, unwrapped)) |name| {
        return std.mem.eql(u8, name, "parseInt") and isUnresolvedReference(symbol_table, unwrapped);
    }

    const member = switch (tree.data(unwrapped)) {
        .member_expression => |member| member,
        else => return false,
    };
    if (member.computed or member.property == .null) return false;

    const property = switch (tree.data(member.property)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        else => return false,
    };
    if (!std.mem.eql(u8, property, "parseInt")) return false;

    const object = unwrapTransparent(tree, member.object);
    const object_name = identifierReferenceName(tree, object) orelse return false;
    return std.mem.eql(u8, object_name, "Number") and isUnresolvedReference(symbol_table, object);
}

fn isDecimalRadix(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const unwrapped = unwrapTransparent(tree, index);

    switch (tree.data(unwrapped)) {
        .numeric_literal => |literal| return isNumericRadix(tree, literal, 1, 10),
        .unary_expression => |expression| {
            if (expression.operator != .positive and expression.operator != .negate) return false;

            const literal = switch (tree.data(unwrapTransparent(tree, expression.argument))) {
                .numeric_literal => |literal| literal,
                else => return false,
            };
            return isNumericRadix(tree, literal, if (expression.operator == .negate) -1 else 1, 10);
        },
        else => return false,
    }
}

fn isValidRadix(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const unwrapped = unwrapTransparent(tree, index);

    switch (tree.data(unwrapped)) {
        .identifier_reference => |identifier| return !std.mem.eql(u8, tree.string(identifier.name), "undefined"),
        .numeric_literal => |literal| return isValidNumericRadix(tree, literal, 1),
        .unary_expression => |expression| {
            if (expression.operator != .positive and expression.operator != .negate) return false;

            const literal = switch (tree.data(unwrapTransparent(tree, expression.argument))) {
                .numeric_literal => |literal| literal,
                else => return false,
            };
            return isValidNumericRadix(tree, literal, if (expression.operator == .negate) -1 else 1);
        },
        .string_literal, .boolean_literal, .null_literal, .bigint_literal => return false,
        else => return true,
    }
}

fn isValidNumericRadix(tree: *const ast.Tree, literal: ast.NumericLiteral, sign: i64) bool {
    const value = literal.value(tree);
    const signed_value = value * @as(f64, @floatFromInt(sign));
    return signed_value >= 2 and signed_value <= 36 and signed_value == @floor(signed_value);
}

fn isNumericRadix(tree: *const ast.Tree, literal: ast.NumericLiteral, sign: i64, expected: i64) bool {
    const value = literal.value(tree);
    const signed_value = value * @as(f64, @floatFromInt(sign));
    return signed_value == @as(f64, @floatFromInt(expected));
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
