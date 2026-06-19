const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "prefer-named-capture-group";

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
        try checkPattern(self.allocator, self.diagnostics, tree, index, pattern);
    }
};

pub fn checkRegExpLiteral(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.RegExpLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkPattern(allocator, diagnostics, tree, index, tree.string(literal.pattern));
}

fn checkPattern(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    pattern: []const u8,
) Allocator.Error!void {
    var scanner = Scanner{};
    scanner.scan(pattern);

    for (scanner.groups[0..scanner.group_count]) |group| {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "Capture group '{s}' should be converted to a named or non-capturing group.",
            .{pattern[group.start..group.end]},
        );
    }
}

const Group = struct {
    start: usize,
    end: usize,
};

const max_groups = 128;

const Scanner = struct {
    groups: [max_groups]Group = undefined,
    group_count: usize = 0,

    fn scan(self: *Scanner, pattern: []const u8) void {
        var index: usize = 0;
        var in_class = false;
        while (index < pattern.len) : (index += 1) {
            const char = pattern[index];
            if (char == '\\') {
                if (index + 1 >= pattern.len) return;
                index += 1;
                continue;
            }

            if (in_class) {
                if (char == ']') in_class = false;
                continue;
            }

            switch (char) {
                '[' => in_class = true,
                '(' => index = self.maybeAddCapture(pattern, index),
                else => {},
            }
        }
    }

    fn maybeAddCapture(self: *Scanner, pattern: []const u8, open_index: usize) usize {
        if (open_index + 1 < pattern.len and pattern[open_index + 1] == '?') {
            if (open_index + 2 >= pattern.len) return open_index + 1;
            switch (pattern[open_index + 2]) {
                ':' => return open_index + 2,
                '=' => return open_index + 2,
                '!' => return open_index + 2,
                '<' => {
                    if (open_index + 3 < pattern.len and (pattern[open_index + 3] == '=' or pattern[open_index + 3] == '!')) {
                        return open_index + 3;
                    }
                    return skipNamedCapturePrefix(pattern, open_index + 2);
                },
                else => return open_index + 2,
            }
        }

        if (self.group_count < max_groups) {
            self.groups[self.group_count] = .{
                .start = open_index,
                .end = findGroupEnd(pattern, open_index),
            };
            self.group_count += 1;
        }
        return open_index;
    }
};

fn findGroupEnd(pattern: []const u8, open_index: usize) usize {
    var index = open_index + 1;
    var depth: usize = 1;
    var in_class = false;
    while (index < pattern.len) : (index += 1) {
        const char = pattern[index];
        if (char == '\\') {
            if (index + 1 >= pattern.len) return pattern.len;
            index += 1;
            continue;
        }
        if (in_class) {
            if (char == ']') in_class = false;
            continue;
        }
        switch (char) {
            '[' => in_class = true,
            '(' => depth += 1,
            ')' => {
                depth -= 1;
                if (depth == 0) return index + 1;
            },
            else => {},
        }
    }
    return pattern.len;
}

fn skipNamedCapturePrefix(pattern: []const u8, less_than_index: usize) usize {
    var index = less_than_index + 1;
    while (index < pattern.len) : (index += 1) {
        if (pattern[index] == '>') return index;
    }
    return less_than_index;
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
