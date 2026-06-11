const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-dupe-else-if";

const Term = struct {
    atoms: std.ArrayList(ast.NodeIndex) = .empty,

    fn deinit(self: *Term, allocator: Allocator) void {
        self.atoms.deinit(allocator);
    }
};

const Dnf = struct {
    terms: std.ArrayList(Term) = .empty,

    fn deinit(self: *Dnf, allocator: Allocator) void {
        for (self.terms.items) |*term| {
            term.deinit(allocator);
        }
        self.terms.deinit(allocator);
    }
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.IfStatement,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (isElseIf(tree, index, ctx)) return;

    var previous: std.ArrayList(ast.NodeIndex) = .empty;
    defer previous.deinit(allocator);

    var current_statement = statement;
    while (current_statement.alternate != .null) {
        const alternate = current_statement.alternate;
        const next_statement = switch (tree.data(alternate)) {
            .if_statement => |next| next,
            else => break,
        };

        try previous.append(allocator, current_statement.@"test");
        if (try isCoveredByPrevious(allocator, tree, next_statement.@"test", previous.items)) {
            try core.addDiagnostic(
                allocator,
                diagnostics,
                .warning,
                id,
                "Unexpected duplicate condition in else-if chain.",
                tree.span(next_statement.@"test"),
            );
        }

        current_statement = next_statement;
    }
}

fn isElseIf(tree: *const ast.Tree, index: ast.NodeIndex, ctx: *traverser.basic.Ctx) bool {
    const parent = ctx.path.parent() orelse return false;
    return switch (tree.data(parent)) {
        .if_statement => |statement| statement.alternate == index,
        else => false,
    };
}

fn isCoveredByPrevious(
    allocator: Allocator,
    tree: *const ast.Tree,
    current: ast.NodeIndex,
    previous: []const ast.NodeIndex,
) Allocator.Error!bool {
    var current_dnf = try buildDnf(allocator, tree, current);
    defer current_dnf.deinit(allocator);

    for (current_dnf.terms.items) |current_term| {
        var covered = false;
        for (previous) |previous_index| {
            var previous_dnf = try buildDnf(allocator, tree, previous_index);
            defer previous_dnf.deinit(allocator);

            if (termCoveredByDnf(tree, current_term, previous_dnf)) {
                covered = true;
                break;
            }
        }
        if (!covered) return false;
    }

    return current_dnf.terms.items.len > 0;
}

fn termCoveredByDnf(tree: *const ast.Tree, current: Term, previous: Dnf) bool {
    for (previous.terms.items) |previous_term| {
        if (termIncludesAll(tree, current, previous_term)) return true;
    }
    return false;
}

fn termIncludesAll(tree: *const ast.Tree, current: Term, previous: Term) bool {
    for (previous.atoms.items) |previous_atom| {
        var found = false;
        for (current.atoms.items) |current_atom| {
            if (sameSource(tree, previous_atom, current_atom)) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }

    return previous.atoms.items.len > 0;
}

fn buildDnf(allocator: Allocator, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!Dnf {
    const unwrapped = unwrapTransparent(tree, index);
    if (unwrapped == .null) return .{};

    if (logicalExpression(tree, unwrapped)) |expression| {
        switch (expression.operator) {
            .@"or" => {
                var left = try buildDnf(allocator, tree, expression.left);
                defer left.deinit(allocator);
                var right = try buildDnf(allocator, tree, expression.right);
                defer right.deinit(allocator);

                var result: Dnf = .{};
                try appendTerms(allocator, &result, left.terms.items);
                try appendTerms(allocator, &result, right.terms.items);
                return result;
            },
            .@"and" => {
                var left = try buildDnf(allocator, tree, expression.left);
                defer left.deinit(allocator);
                var right = try buildDnf(allocator, tree, expression.right);
                defer right.deinit(allocator);

                return try andDnf(allocator, left, right);
            },
            .nullish_coalescing => {},
        }
    }

    var term: Term = .{};
    errdefer term.deinit(allocator);
    try term.atoms.append(allocator, unwrapped);

    var result: Dnf = .{};
    errdefer result.deinit(allocator);
    try result.terms.append(allocator, term);
    return result;
}

fn appendTerms(allocator: Allocator, out: *Dnf, terms: []const Term) Allocator.Error!void {
    for (terms) |term| {
        try out.terms.append(allocator, try cloneTerm(allocator, term));
    }
}

fn andDnf(allocator: Allocator, left: Dnf, right: Dnf) Allocator.Error!Dnf {
    var result: Dnf = .{};
    errdefer result.deinit(allocator);

    for (left.terms.items) |left_term| {
        for (right.terms.items) |right_term| {
            var combined = try cloneTerm(allocator, left_term);
            errdefer combined.deinit(allocator);
            try combined.atoms.appendSlice(allocator, right_term.atoms.items);
            try result.terms.append(allocator, combined);
        }
    }

    return result;
}

fn cloneTerm(allocator: Allocator, term: Term) Allocator.Error!Term {
    var clone: Term = .{};
    errdefer clone.deinit(allocator);
    try clone.atoms.appendSlice(allocator, term.atoms.items);
    return clone;
}

fn logicalExpression(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.LogicalExpression {
    return switch (tree.data(index)) {
        .logical_expression => |expression| expression,
        else => null,
    };
}

fn sameSource(tree: *const ast.Tree, left: ast.NodeIndex, right: ast.NodeIndex) bool {
    const left_source = nodeSource(tree, left) orelse return false;
    const right_source = nodeSource(tree, right) orelse return false;
    return std.mem.eql(u8, left_source, right_source);
}

fn nodeSource(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    const span = tree.span(unwrapTransparent(tree, index));
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);

    if (start >= end or end > tree.source.len) return null;
    return std.mem.trim(u8, tree.source[start..end], " \t\r\n");
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
