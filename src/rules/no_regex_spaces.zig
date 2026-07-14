const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = @import("../semantic_compat.zig").traverser;
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

        const pattern_node = unwrapTransparent(tree, arguments[0]);
        const literal = switch (tree.data(pattern_node)) {
            .string_literal => |literal| literal,
            else => return,
        };
        const pattern = tree.string(literal.value);
        const raw = tree.string(literal.raw);
        if (raw.len < 2) return;

        const raw_pattern = raw[1 .. raw.len - 1];
        if (std.mem.indexOf(u8, raw_pattern, "  ") == null) return;
        const space_run = firstConsecutiveSpaceRun(pattern) orelse return;

        const has_static_flags = arguments.len < 2 or stringLiteralValue(tree, arguments[1]) != null;
        const fix_span: ?ast.Span = if (has_static_flags and std.mem.eql(u8, raw_pattern, pattern)) blk: {
            const pattern_span = tree.span(pattern_node);
            const start = pattern_span.start + 1 + @as(u32, @intCast(space_run.start));
            break :blk .{ .start = start, .end = start + @as(u32, @intCast(space_run.len)) };
        } else null;

        try addDiagnostic(self.allocator, self.diagnostics, tree, index, space_run.len, fix_span);
    }
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.RegExpLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const space_run = firstConsecutiveSpaceRun(tree.string(literal.pattern)) orelse return;
    const literal_span = tree.span(index);
    const start = literal_span.start + 1 + @as(u32, @intCast(space_run.start));

    try addDiagnostic(
        allocator,
        diagnostics,
        tree,
        index,
        space_run.len,
        .{ .start = start, .end = start + @as(u32, @intCast(space_run.len)) },
    );
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    space_count: usize,
    fix_span: ?ast.Span,
) Allocator.Error!void {
    if (fix_span) |span| {
        const replacement = try std.fmt.allocPrint(allocator, " {{{d}}}", .{space_count});
        defer allocator.free(replacement);

        try core.addDiagnosticWithFix(
            allocator,
            diagnostics,
            .warning,
            id,
            "Avoid multiple spaces in regular expression literals.",
            tree.span(index),
            .{ .span = span, .replacement = replacement },
        );
    } else {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Avoid multiple spaces in regular expression literals.",
            tree.span(index),
        );
    }
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

const SpaceRun = struct {
    start: usize,
    len: usize,
};

fn firstConsecutiveSpaceRun(pattern: []const u8) ?SpaceRun {
    var in_class = false;
    var escaped = false;
    var run_start: usize = 0;
    var run_len: usize = 0;

    for (pattern, 0..) |char, index| {
        const escaped_char = escaped;
        if (escaped) {
            escaped = false;
        } else if (char == '\\') {
            if (reportableRun(run_start, run_len, char)) |space_run| return space_run;
            run_len = 0;
            escaped = true;
            continue;
        }

        if (!escaped_char and char == '[') {
            if (reportableRun(run_start, run_len, char)) |space_run| return space_run;
            run_len = 0;
            in_class = true;
            continue;
        }
        if (!escaped_char and char == ']') {
            run_len = 0;
            in_class = false;
            continue;
        }

        if (!in_class and char == ' ') {
            if (run_len == 0) run_start = index;
            run_len += 1;
            continue;
        }

        if (!in_class) {
            if (reportableRun(run_start, run_len, char)) |space_run| return space_run;
        }
        run_len = 0;
    }

    return reportableRun(run_start, run_len, null);
}

fn reportableRun(start: usize, len: usize, next: ?u8) ?SpaceRun {
    const count = if (next != null and isQuantifierStart(next.?)) len -| 1 else len;
    if (count < 2) return null;
    return .{ .start = start, .len = count };
}

fn isQuantifierStart(char: u8) bool {
    return switch (char) {
        '+', '*', '{', '?' => true,
        else => false,
    };
}
