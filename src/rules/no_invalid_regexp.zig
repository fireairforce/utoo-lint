const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-invalid-regexp";

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
        try self.check(ctx.tree, call.callee, call.arguments, index);
        return .proceed;
    }

    pub fn enter_new_expression(
        self: *Visitor,
        expression: ast.NewExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.check(ctx.tree, expression.callee, expression.arguments, index);
        return .proceed;
    }

    fn check(
        self: *Visitor,
        tree: *const ast.Tree,
        callee: ast.NodeIndex,
        argument_range: ast.IndexRange,
        index: ast.NodeIndex,
    ) Allocator.Error!void {
        const arguments = tree.extra(argument_range);
        if (arguments.len == 0) return;
        if (!isGlobalRegExpReference(tree, self.symbol_table, callee)) return;

        const flags = if (arguments.len >= 2) stringLiteralValue(tree, arguments[1]) else null;
        if (flags) |value| {
            if (validateFlags(value)) |message| {
                try self.addDiagnostic(tree, index, message);
                return;
            }
        }

        const pattern = stringLiteralValue(tree, arguments[0]) orelse return;
        const message = validatePattern(pattern) orelse return;
        try self.addDiagnostic(tree, index, message);
    }

    fn addDiagnostic(
        self: *Visitor,
        tree: *const ast.Tree,
        index: ast.NodeIndex,
        message: []const u8,
    ) Allocator.Error!void {
        try core.addDiagnosticFmt(
            self.allocator,
            self.diagnostics,
            .warning,
            id,
            tree.span(index),
            "Invalid regular expression: {s}.",
            .{message},
        );
    }
};

fn validateFlags(flags: []const u8) ?[]const u8 {
    var seen: u32 = 0;

    for (flags) |flag| {
        const valid = switch (flag) {
            'd', 'g', 'i', 'm', 's', 'u', 'v', 'y' => true,
            else => false,
        };
        if (!valid) return "invalid flags";

        const bit: u5 = @intCast(flag - 'a');
        if ((seen & (@as(u32, 1) << bit)) != 0) return "duplicate flags";
        seen |= @as(u32, 1) << bit;
    }

    const u_bit = @as(u32, 1) << ('u' - 'a');
    const v_bit = @as(u32, 1) << ('v' - 'a');
    if ((seen & u_bit) != 0 and (seen & v_bit) != 0) return "incompatible flags";

    return null;
}

fn validatePattern(pattern: []const u8) ?[]const u8 {
    var group_depth: usize = 0;
    var in_class = false;
    var escaped = false;

    for (pattern) |char| {
        if (escaped) {
            escaped = false;
            continue;
        }

        if (char == '\\') {
            escaped = true;
            continue;
        }

        if (in_class) {
            if (char == ']') in_class = false;
            continue;
        }

        switch (char) {
            '[' => in_class = true,
            '(' => group_depth += 1,
            ')' => {
                if (group_depth == 0) return "unmatched ')'";
                group_depth -= 1;
            },
            else => {},
        }
    }

    if (escaped) return "trailing escape";
    if (in_class) return "unterminated character class";
    if (group_depth != 0) return "unterminated group";

    return null;
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
