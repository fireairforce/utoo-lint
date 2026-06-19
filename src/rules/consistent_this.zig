const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "consistent-this";

const max_scopes = 64;
const max_pending_aliases = 64;
const max_assigned_aliases = 64;

pub const State = struct {
    scopes: [max_scopes]Scope = undefined,
    scope_count: usize = 0,

    pub fn enterScope(self: *State) void {
        if (self.scope_count >= max_scopes) return;
        self.scopes[self.scope_count] = .{};
        self.scope_count += 1;
    }

    pub fn exitScope(
        self: *State,
        allocator: Allocator,
        diagnostics: *core.DiagnosticList,
    ) Allocator.Error!void {
        if (self.scope_count == 0) return;
        self.scope_count -= 1;
        const scope = self.scopes[self.scope_count];
        for (scope.pending[0..scope.pending_count]) |pending| {
            if (pending.assigned) continue;
            try reportAliasNotAssignedToThis(allocator, diagnostics, pending.span, pending.name);
        }
    }

    pub fn rememberPendingAlias(self: *State, name: []const u8, span: ast.Span) void {
        if (self.scope_count == 0) return;
        var scope = &self.scopes[self.scope_count - 1];
        if (scope.pending_count >= max_pending_aliases) return;
        scope.pending[scope.pending_count] = .{
            .name = name,
            .span = span,
            .assigned = scope.hasAssigned(name),
        };
        scope.pending_count += 1;
    }

    pub fn markAssigned(self: *State, name: []const u8) void {
        if (self.scope_count == 0) return;
        var scope = &self.scopes[self.scope_count - 1];
        scope.rememberAssigned(name);
        for (scope.pending[0..scope.pending_count]) |*pending| {
            if (std.mem.eql(u8, pending.name, name)) {
                pending.assigned = true;
            }
        }
    }
};

const Scope = struct {
    pending: [max_pending_aliases]PendingAlias = undefined,
    pending_count: usize = 0,
    assigned: [max_assigned_aliases][]const u8 = undefined,
    assigned_count: usize = 0,

    fn hasAssigned(self: *const Scope, name: []const u8) bool {
        for (self.assigned[0..self.assigned_count]) |assigned| {
            if (std.mem.eql(u8, assigned, name)) return true;
        }
        return false;
    }

    fn rememberAssigned(self: *Scope, name: []const u8) void {
        if (self.hasAssigned(name)) return;
        if (self.assigned_count >= max_assigned_aliases) return;
        self.assigned[self.assigned_count] = name;
        self.assigned_count += 1;
    }
};

const PendingAlias = struct {
    name: []const u8,
    span: ast.Span,
    assigned: bool = false,
};

pub fn checkVariableDeclarator(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declarator: ast.VariableDeclarator,
    index: ast.NodeIndex,
    state: *State,
    aliases: *const core.ConsistentThisAliases,
) Allocator.Error!void {
    const name = bindingIdentifierName(tree, declarator.id) orelse return;

    if (declarator.init == .null) {
        if (aliases.contains(name)) {
            state.rememberPendingAlias(name, tree.span(index));
        }
        return;
    }

    try checkAssignment(allocator, diagnostics, tree, tree.span(index), name, declarator.init, true, state, aliases);
}

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    index: ast.NodeIndex,
    state: *State,
    aliases: *const core.ConsistentThisAliases,
) Allocator.Error!void {
    const name = identifierReferenceName(tree, expression.left) orelse return;
    try checkAssignment(
        allocator,
        diagnostics,
        tree,
        tree.span(index),
        name,
        expression.right,
        expression.operator == .assign,
        state,
        aliases,
    );
}

fn checkAssignment(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    span: ast.Span,
    name: []const u8,
    value: ast.NodeIndex,
    simple_assignment: bool,
    state: *State,
    aliases: *const core.ConsistentThisAliases,
) Allocator.Error!void {
    const assigns_this = isThisExpression(tree, value);

    if (aliases.contains(name)) {
        if (!assigns_this or !simple_assignment) {
            try reportAliasNotAssignedToThis(allocator, diagnostics, span, name);
            return;
        }
        state.markAssigned(name);
        return;
    }

    if (assigns_this) {
        try reportUnexpectedAlias(allocator, diagnostics, span, name);
    }
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn identifierReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isThisExpression(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .this_expression => true,
        else => false,
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

fn reportAliasNotAssignedToThis(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    span: ast.Span,
    name: []const u8,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        span,
        "Designated alias '{s}' is not assigned to 'this'.",
        .{name},
    );
}

fn reportUnexpectedAlias(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    span: ast.Span,
    name: []const u8,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        span,
        "Unexpected alias '{s}' for 'this'.",
        .{name},
    );
}
