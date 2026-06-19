const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "prefer-const";

const SymbolId = traverser.semantic.SymbolId;
const DeclSymbolMap = std.AutoHashMap(ast.NodeIndex, SymbolId);
const ReferenceLookup = std.AutoHashMap(ast.NodeIndex, SymbolId);
const DestructuringGroupMap = std.AutoHashMap(usize, bool);

pub const Destructuring = enum {
    any,
    all,
};

pub const Options = struct {
    destructuring: Destructuring = .any,
    ignore_read_before_assign: bool = true,
};

const Candidate = struct {
    node: ast.NodeIndex,
    name: []const u8,
    initialized: bool = true,
    reassigned: bool = false,
    assignment_count: usize = 0,
    first_assignment_node: ast.NodeIndex = .null,
    first_assignment_end: u32 = 0,
    read_before_assignment: bool = false,
    destructuring_group: ?usize = null,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
) Allocator.Error!void {
    return runWithOptions(allocator, diagnostics, tree, symbol_table, .{});
}

pub fn runWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: traverser.semantic.SymbolTable,
    options: Options,
) Allocator.Error!void {
    var decl_symbols = DeclSymbolMap.init(allocator);
    defer decl_symbols.deinit();

    var reference_lookup = ReferenceLookup.init(allocator);
    defer reference_lookup.deinit();

    var destructuring_groups = DestructuringGroupMap.init(allocator);
    defer destructuring_groups.deinit();

    const candidate_symbols = try allocator.alloc(bool, symbol_table.symbols.len);
    defer allocator.free(candidate_symbols);
    @memset(candidate_symbols, false);

    var candidates = std.AutoHashMap(SymbolId, Candidate).init(allocator);
    defer candidates.deinit();

    var symbol_iter = symbol_table.iterSymbols();
    while (symbol_iter.next()) |entry| {
        const symbol = entry.symbol;
        if (!symbol.flags.block_scoped_var or symbol.flags.const_var) continue;
        candidate_symbols[@intFromEnum(entry.id)] = true;
        for (symbol_table.symbolDecls(entry.id)) |decl| {
            try decl_symbols.put(decl, entry.id);
        }
    }

    var ref_iter = symbol_table.iterReferences();
    while (ref_iter.next()) |entry| {
        const symbol_id = symbol_table.referenceSymbol(entry.id);
        if (symbol_id == .none) continue;

        const symbol_index = @intFromEnum(symbol_id);
        if (symbol_index >= candidate_symbols.len or !candidate_symbols[symbol_index]) continue;

        try reference_lookup.put(entry.reference.node, symbol_id);
    }

    var visitor = Visitor{
        .allocator = allocator,
        .decl_symbols = &decl_symbols,
        .reference_lookup = &reference_lookup,
        .candidates = &candidates,
        .destructuring_groups = &destructuring_groups,
        .options = options,
    };
    try traverser.basic.traverse(Visitor, tree, &visitor);

    var candidate_iter = candidates.iterator();
    while (candidate_iter.next()) |entry| {
        const candidate = entry.value_ptr.*;
        if (candidate.reassigned) continue;
        const report_node = if (candidate.initialized) candidate.node else report_node: {
            if (candidate.assignment_count != 1) continue;
            if (options.ignore_read_before_assign and candidate.read_before_assignment) continue;
            break :report_node candidate.first_assignment_node;
        };
        if (candidate.destructuring_group) |group_id| {
            if (options.destructuring == .all and (destructuring_groups.get(group_id) orelse false)) continue;
        }

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(report_node),
            "'{s}' is never reassigned. Use 'const' instead.",
            .{candidate.name},
        );
    }
}

const Visitor = struct {
    allocator: Allocator,
    decl_symbols: *const DeclSymbolMap,
    reference_lookup: *const ReferenceLookup,
    candidates: *std.AutoHashMap(SymbolId, Candidate),
    destructuring_groups: *DestructuringGroupMap,
    options: Options,
    next_destructuring_group: usize = 0,

    pub fn enter_variable_declaration(
        self: *Visitor,
        declaration: ast.VariableDeclaration,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        if (declaration.kind != .let) return .proceed;

        for (ctx.tree.extra(declaration.declarators)) |declarator_index| {
            const declarator = switch (ctx.tree.data(declarator_index)) {
                .variable_declarator => |declarator| declarator,
                else => continue,
            };

            const group = if (self.options.destructuring == .all and isDestructuringPattern(ctx.tree, declarator.id)) group: {
                const group_id = self.next_destructuring_group;
                self.next_destructuring_group += 1;
                try self.destructuring_groups.put(group_id, false);
                break :group group_id;
            } else null;

            try self.collectCandidate(ctx.tree, declarator.id, group, declarator.init != .null);
        }

        return .proceed;
    }

    pub fn enter_assignment_expression(
        self: *Visitor,
        expression: ast.AssignmentExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.markAssignment(ctx.tree, expression.left, expression.operator == .assign, ctx.tree.span(index).end);
        return .proceed;
    }

    pub fn enter_for_in_statement(
        self: *Visitor,
        statement: ast.ForInStatement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.collectForLoopLeft(ctx.tree, statement.left);
        return .proceed;
    }

    pub fn enter_for_of_statement(
        self: *Visitor,
        statement: ast.ForOfStatement,
        _: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.collectForLoopLeft(ctx.tree, statement.left);
        return .proceed;
    }

    pub fn enter_update_expression(
        self: *Visitor,
        expression: ast.UpdateExpression,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) Allocator.Error!traverser.Action {
        try self.markAssignment(ctx.tree, expression.argument, false, ctx.tree.span(index).end);
        return .proceed;
    }

    fn collectForLoopLeft(self: *Visitor, tree: *const ast.Tree, index: ast.NodeIndex) Allocator.Error!void {
        const declaration = switch (tree.data(index)) {
            .variable_declaration => |declaration| declaration,
            else => return,
        };
        if (declaration.kind != .let) return;

        for (tree.extra(declaration.declarators)) |declarator_index| {
            const declarator = switch (tree.data(declarator_index)) {
                .variable_declarator => |declarator| declarator,
                else => continue,
            };

            const group = if (self.options.destructuring == .all and isDestructuringPattern(tree, declarator.id)) group: {
                const group_id = self.next_destructuring_group;
                self.next_destructuring_group += 1;
                try self.destructuring_groups.put(group_id, false);
                break :group group_id;
            } else null;

            try self.collectCandidate(tree, declarator.id, group, true);
        }
    }

    pub fn enter_identifier_reference(
        self: *Visitor,
        _: ast.IdentifierReference,
        index: ast.NodeIndex,
        ctx: *traverser.basic.Ctx,
    ) traverser.Action {
        if (isAssignmentWrite(ctx.tree, index, ctx)) return .proceed;

        const symbol_id = self.reference_lookup.get(index) orelse return .proceed;
        if (self.candidates.getPtr(symbol_id)) |candidate| {
            if (!candidate.initialized and isReadBeforeFirstAssignment(ctx.tree, index, candidate.*)) {
                candidate.read_before_assignment = true;
            }
        }

        return .proceed;
    }

    fn collectCandidate(
        self: *Visitor,
        tree: *const ast.Tree,
        index: ast.NodeIndex,
        group: ?usize,
        initialized: bool,
    ) Allocator.Error!void {
        if (index == .null) return;

        switch (tree.data(index)) {
            .binding_identifier => |identifier| {
                const symbol_id = self.decl_symbols.get(index) orelse return;
                if (!initialized) {
                    if (self.candidates.get(symbol_id)) |existing| {
                        if (existing.initialized) return;
                    }
                }
                try self.candidates.put(symbol_id, .{
                    .node = index,
                    .name = tree.string(identifier.name),
                    .initialized = initialized,
                    .destructuring_group = group,
                });
            },
            .assignment_pattern => |pattern| try self.collectCandidate(tree, pattern.left, group, initialized),
            .binding_rest_element => |element| try self.collectCandidate(tree, element.argument, group, initialized),
            .array_pattern => |pattern| {
                for (tree.extra(pattern.elements)) |element| {
                    try self.collectCandidate(tree, element, group, initialized);
                }
                try self.collectCandidate(tree, pattern.rest, group, initialized);
            },
            .object_pattern => |pattern| {
                for (tree.extra(pattern.properties)) |property_index| {
                    const property = switch (tree.data(property_index)) {
                        .binding_property => |property| property,
                        else => continue,
                    };
                    try self.collectCandidate(tree, property.value, group, initialized);
                }
                try self.collectCandidate(tree, pattern.rest, group, initialized);
            },
            else => {},
        }
    }

    fn markAssignment(
        self: *Visitor,
        tree: *const ast.Tree,
        index: ast.NodeIndex,
        simple_assign: bool,
        assignment_end: u32,
    ) Allocator.Error!void {
        if (index == .null) return;

        const unwrapped = unwrapTransparent(tree, index);
        switch (tree.data(unwrapped)) {
            .identifier_reference => {
                const symbol_id = self.reference_lookup.get(unwrapped) orelse return;
                if (self.candidates.getPtr(symbol_id)) |candidate| {
                    if (candidate.initialized) {
                        candidate.reassigned = true;
                    } else if (simple_assign) {
                        candidate.assignment_count += 1;
                        if (candidate.assignment_count == 1) {
                            candidate.first_assignment_node = unwrapped;
                            candidate.first_assignment_end = assignment_end;
                        } else {
                            candidate.reassigned = true;
                        }
                    } else {
                        candidate.reassigned = true;
                    }
                    if (candidate.destructuring_group) |group_id| {
                        try self.destructuring_groups.put(group_id, true);
                    }
                }
            },
            .assignment_pattern => |pattern| try self.markAssignment(tree, pattern.left, simple_assign, assignment_end),
            .array_pattern => |pattern| {
                for (tree.extra(pattern.elements)) |element| {
                    try self.markAssignment(tree, element, simple_assign, assignment_end);
                }
                try self.markAssignment(tree, pattern.rest, simple_assign, assignment_end);
            },
            .object_pattern => |pattern| {
                for (tree.extra(pattern.properties)) |property_index| {
                    const property = switch (tree.data(property_index)) {
                        .binding_property => |property| property,
                        else => continue,
                    };
                    try self.markAssignment(tree, property.value, simple_assign, assignment_end);
                }
                try self.markAssignment(tree, pattern.rest, simple_assign, assignment_end);
            },
            else => {},
        }
    }
};

fn isReadBeforeFirstAssignment(tree: *const ast.Tree, index: ast.NodeIndex, candidate: Candidate) bool {
    if (candidate.assignment_count == 0) return true;
    if (candidate.assignment_count > 1 or candidate.first_assignment_end == 0) return false;
    return tree.span(index).start <= candidate.first_assignment_end;
}

fn isAssignmentWrite(tree: *const ast.Tree, index: ast.NodeIndex, ctx: *traverser.basic.Ctx) bool {
    const parent = ctx.path.parent() orelse return false;

    return switch (tree.data(parent)) {
        .assignment_expression => |expression| unwrapTransparent(tree, expression.left) == index,
        .update_expression => |expression| unwrapTransparent(tree, expression.argument) == index,
        else => false,
    };
}

fn isDestructuringPattern(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .array_pattern,
        .object_pattern,
        => true,
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
