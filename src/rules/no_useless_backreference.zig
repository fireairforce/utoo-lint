const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-useless-backreference";

const max_groups = 128;
const max_backreferences = 128;
const max_scopes = 128;

const ProblemKind = enum {
    nested,
    forward,
    disjunctive,
    into_negative_lookaround,
};

const Scope = struct {
    capture: ?usize = null,
    alternative: usize,
    negative_lookaround: bool = false,
};

const Group = struct {
    start: usize,
    end: usize = 0,
    alternative: usize,
    negative_lookaround: bool,
};

const Backreference = struct {
    start: usize,
    end: usize,
    target: usize,
    alternative: usize,
    negative_lookaround: bool,
    nested: bool,
};

const Problem = struct {
    kind: ProblemKind,
    backreference: Backreference,
    group: Group,
};

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

    for (scanner.backreferences[0..scanner.backreference_count]) |backreference| {
        const problem = scanner.problemFor(backreference) orelse continue;
        try addDiagnostic(allocator, diagnostics, tree, index, pattern, problem);
    }
}

const Scanner = struct {
    groups: [max_groups]Group = undefined,
    group_count: usize = 0,
    backreferences: [max_backreferences]Backreference = undefined,
    backreference_count: usize = 0,
    scopes: [max_scopes]Scope = undefined,
    scope_count: usize = 0,
    next_alternative: usize = 1,

    fn scan(self: *Scanner, pattern: []const u8) void {
        self.scopes[0] = .{ .alternative = 0 };
        self.scope_count = 1;

        var index: usize = 0;
        var in_class = false;
        while (index < pattern.len) : (index += 1) {
            const char = pattern[index];
            if (char == '\\') {
                if (index + 1 >= pattern.len) return;
                if (!in_class and std.ascii.isDigit(pattern[index + 1]) and pattern[index + 1] != '0') {
                    index = self.addBackreference(pattern, index);
                } else {
                    index += 1;
                }
                continue;
            }

            if (in_class) {
                if (char == ']') in_class = false;
                continue;
            }

            switch (char) {
                '[' => in_class = true,
                '(' => index = self.enterGroup(pattern, index),
                ')' => self.exitGroup(index + 1),
                '|' => self.rotateAlternative(),
                else => {},
            }
        }
    }

    fn addBackreference(self: *Scanner, pattern: []const u8, slash_index: usize) usize {
        var digit_end = slash_index + 1;
        var target: usize = 0;
        while (digit_end < pattern.len and std.ascii.isDigit(pattern[digit_end])) : (digit_end += 1) {
            target = target * 10 + (pattern[digit_end] - '0');
        }

        if (self.backreference_count < max_backreferences) {
            self.backreferences[self.backreference_count] = .{
                .start = slash_index,
                .end = digit_end,
                .target = target,
                .alternative = self.currentAlternative(),
                .negative_lookaround = self.inNegativeLookaround(),
                .nested = self.isOpenCapture(target),
            };
            self.backreference_count += 1;
        }

        return digit_end - 1;
    }

    fn enterGroup(self: *Scanner, pattern: []const u8, open_index: usize) usize {
        var capturing = true;
        var negative_lookaround = false;
        var skip_to = open_index;

        if (open_index + 1 < pattern.len and pattern[open_index + 1] == '?') {
            capturing = false;
            if (open_index + 2 < pattern.len) {
                switch (pattern[open_index + 2]) {
                    ':' => skip_to = open_index + 2,
                    '=' => skip_to = open_index + 2,
                    '!' => {
                        negative_lookaround = true;
                        skip_to = open_index + 2;
                    },
                    '<' => {
                        if (open_index + 3 < pattern.len and (pattern[open_index + 3] == '=' or pattern[open_index + 3] == '!')) {
                            negative_lookaround = pattern[open_index + 3] == '!';
                            skip_to = open_index + 3;
                        } else {
                            capturing = true;
                            skip_to = skipNamedCapturePrefix(pattern, open_index + 2);
                        }
                    },
                    else => skip_to = open_index + 2,
                }
            }
        }

        var capture_id: ?usize = null;
        if (capturing and self.group_count < max_groups) {
            capture_id = self.group_count + 1;
            self.groups[self.group_count] = .{
                .start = open_index,
                .alternative = self.currentAlternative(),
                .negative_lookaround = self.inNegativeLookaround() or negative_lookaround,
            };
            self.group_count += 1;
        }

        if (self.scope_count < max_scopes) {
            self.scopes[self.scope_count] = .{
                .capture = capture_id,
                .alternative = self.nextAlternative(),
                .negative_lookaround = negative_lookaround,
            };
            self.scope_count += 1;
        }

        return skip_to;
    }

    fn exitGroup(self: *Scanner, end: usize) void {
        if (self.scope_count <= 1) return;
        const scope = self.scopes[self.scope_count - 1];
        if (scope.capture) |capture_id| {
            if (capture_id > 0 and capture_id <= self.group_count) {
                self.groups[capture_id - 1].end = end;
            }
        }
        self.scope_count -= 1;
    }

    fn rotateAlternative(self: *Scanner) void {
        if (self.scope_count == 0) return;
        self.scopes[self.scope_count - 1].alternative = self.nextAlternative();
    }

    fn nextAlternative(self: *Scanner) usize {
        const alternative = self.next_alternative;
        self.next_alternative += 1;
        return alternative;
    }

    fn currentAlternative(self: *const Scanner) usize {
        if (self.scope_count == 0) return 0;
        return self.scopes[self.scope_count - 1].alternative;
    }

    fn inNegativeLookaround(self: *const Scanner) bool {
        for (self.scopes[0..self.scope_count]) |scope| {
            if (scope.negative_lookaround) return true;
        }
        return false;
    }

    fn isOpenCapture(self: *const Scanner, target: usize) bool {
        for (self.scopes[0..self.scope_count]) |scope| {
            if (scope.capture != null and scope.capture.? == target) return true;
        }
        return false;
    }

    fn problemFor(self: *const Scanner, backreference: Backreference) ?Problem {
        if (backreference.target == 0 or backreference.target > self.group_count) return null;
        const group = self.groups[backreference.target - 1];
        if (group.end == 0) return null;

        if (backreference.nested) {
            return .{ .kind = .nested, .backreference = backreference, .group = group };
        }
        if (backreference.end <= group.start) {
            return .{ .kind = .forward, .backreference = backreference, .group = group };
        }
        if (group.negative_lookaround and !backreference.negative_lookaround) {
            return .{ .kind = .into_negative_lookaround, .backreference = backreference, .group = group };
        }
        if (group.alternative != backreference.alternative) {
            return .{ .kind = .disjunctive, .backreference = backreference, .group = group };
        }
        return null;
    }
};

fn skipNamedCapturePrefix(pattern: []const u8, less_than_index: usize) usize {
    var index = less_than_index + 1;
    while (index < pattern.len) : (index += 1) {
        if (pattern[index] == '>') return index;
    }
    return less_than_index;
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    pattern: []const u8,
    problem: Problem,
) Allocator.Error!void {
    const backreference = pattern[problem.backreference.start..problem.backreference.end];
    const group = pattern[problem.group.start..problem.group.end];
    const reason = switch (problem.kind) {
        .nested => "from within that group",
        .forward => "which appears later in the pattern",
        .disjunctive => "which is in another alternative",
        .into_negative_lookaround => "which is in a negative lookaround",
    };

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Backreference '{s}' will be ignored. It references group '{s}' {s}.",
        .{ backreference, group, reason },
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
