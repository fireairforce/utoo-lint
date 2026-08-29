const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const semantic_compat = @import("../semantic_compat.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;
const SymbolId = semantic_compat.traverser.semantic.SymbolId;

pub const id = "no-unmodified-loop-condition";

const Condition = struct {
    node: ast.NodeIndex,
    name: ast.String,
    symbol: SymbolId,
    group: ast.NodeIndex = .null,
    loop: ast.NodeIndex,
    modified: bool = false,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    symbol_table: semantic_compat.SymbolTable,
) Allocator.Error!void {
    var conditions: std.ArrayList(Condition) = .empty;
    defer conditions.deinit(allocator);

    var references = symbol_table.iterReferences();
    while (references.next()) |entry| {
        if (entry.reference.kind != .value) continue;
        const symbol = symbol_table.referenceSymbol(entry.id);
        if (symbol == .none) continue;

        if (try toLoopCondition(tree, symbol_table, entry.reference.node, entry.reference.name, symbol)) |condition| {
            try conditions.append(allocator, condition);
        }
    }

    if (conditions.items.len == 0) return;

    for (conditions.items) |*condition| {
        condition.modified = isModified(tree, symbol_table, condition.*);
    }

    for (conditions.items) |condition| {
        if (!condition.modified and condition.group == .null) {
            try report(allocator, diagnostics, tree, condition);
        }
    }

    var checked_groups = std.AutoHashMap(ast.NodeIndex, void).init(allocator);
    defer checked_groups.deinit();

    for (conditions.items) |condition| {
        if (condition.group == .null or checked_groups.contains(condition.group)) continue;
        try checked_groups.put(condition.group, {});

        var all_unmodified = true;
        for (conditions.items) |group_condition| {
            if (group_condition.group == condition.group and group_condition.modified) {
                all_unmodified = false;
                break;
            }
        }
        if (!all_unmodified) continue;

        for (conditions.items) |group_condition| {
            if (group_condition.group == condition.group) {
                try report(allocator, diagnostics, tree, group_condition);
            }
        }
    }
}

fn toLoopCondition(
    tree: *const ast.Tree,
    symbol_table: semantic_compat.SymbolTable,
    reference_node: ast.NodeIndex,
    name: ast.String,
    symbol: SymbolId,
) Allocator.Error!?Condition {
    var group: ast.NodeIndex = .null;
    var child = reference_node;
    var maybe_node = symbol_table.parentOf(child);

    while (maybe_node) |node| {
        const data = tree.data(node);

        if (isSentinel(data)) {
            if (loopTest(data)) |test_node| {
                if (test_node == child) {
                    return .{
                        .node = reference_node,
                        .name = name,
                        .symbol = symbol,
                        .group = group,
                        .loop = node,
                    };
                }
            }
            break;
        }

        switch (data) {
            .binary_expression, .conditional_expression => {
                if (containsDynamicExpression(tree, node)) break;
                group = node;
            },
            else => {},
        }

        child = node;
        maybe_node = symbol_table.parentOf(node);
    }

    return null;
}

fn isModified(
    tree: *const ast.Tree,
    symbol_table: semantic_compat.SymbolTable,
    condition: Condition,
) bool {
    var uses = symbol_table.symbolUses(condition.symbol);
    while (uses.next()) |reference| {
        const reference_id = symbol_table.model.referenceOf(reference) orelse continue;
        if (!symbol_table.isWriteReference(reference_id)) continue;

        if (isInLoop(tree, condition.loop, reference)) return true;
        if (enclosingFunctionCalledInLoop(tree, symbol_table, condition.loop, reference)) return true;
    }

    // Yuku does not model declaration initializers as references. ESLint counts
    // initialized `var` declarations as writes, so synthesize those modifiers.
    for (symbol_table.symbolDecls(condition.symbol)) |declaration| {
        if (isInitializedVarDeclaration(tree, symbol_table, declaration) and
            isInLoop(tree, condition.loop, declaration))
        {
            return true;
        }
    }

    return false;
}

fn isInitializedVarDeclaration(
    tree: *const ast.Tree,
    symbol_table: semantic_compat.SymbolTable,
    declaration: ast.NodeIndex,
) bool {
    var child = declaration;
    var declarator_index: ast.NodeIndex = .null;
    var declarator: ast.VariableDeclarator = undefined;
    while (symbol_table.parentOf(child)) |parent| {
        const parent_data = tree.data(parent);
        switch (parent_data) {
            .variable_declarator => |value| {
                declarator_index = parent;
                declarator = value;
                break;
            },
            else => if (parent_data.isDeclaration()) return false,
        }
        child = parent;
    }
    if (declarator_index == .null) return false;
    if (declarator.init == .null) return false;

    const declaration_index = symbol_table.parentOf(declarator_index) orelse return false;
    return switch (tree.data(declaration_index)) {
        .variable_declaration => |value| value.kind == .@"var",
        else => false,
    };
}

fn enclosingFunctionCalledInLoop(
    tree: *const ast.Tree,
    symbol_table: semantic_compat.SymbolTable,
    loop: ast.NodeIndex,
    modifier: ast.NodeIndex,
) bool {
    var maybe_node: ?ast.NodeIndex = modifier;
    while (maybe_node) |node| {
        switch (tree.data(node)) {
            .function => |function| {
                if (function.type == .function_declaration and function.id != .null) {
                    const function_symbol = symbol_table.symbolOf(function.id) orelse return false;
                    var uses = symbol_table.symbolUses(function_symbol);
                    while (uses.next()) |use| {
                        if (isInLoop(tree, loop, use)) return true;
                    }
                    return false;
                }
            },
            else => {},
        }
        maybe_node = symbol_table.parentOf(node);
    }
    return false;
}

fn isInLoop(tree: *const ast.Tree, loop: ast.NodeIndex, node: ast.NodeIndex) bool {
    const loop_span = tree.span(loop);
    const node_span = tree.span(node);
    if (node_span.start < loop_span.start or node_span.end > loop_span.end) return false;

    return switch (tree.data(loop)) {
        .for_statement => |statement| statement.init == .null or !containsNode(tree, statement.init, node),
        else => true,
    };
}

fn containsNode(tree: *const ast.Tree, container: ast.NodeIndex, node: ast.NodeIndex) bool {
    const outer = tree.span(container);
    const inner = tree.span(node);
    return outer.start <= inner.start and inner.end <= outer.end;
}

fn loopTest(data: ast.NodeData) ?ast.NodeIndex {
    return switch (data) {
        .while_statement => |statement| statement.@"test",
        .do_while_statement => |statement| statement.@"test",
        .for_statement => |statement| statement.@"test",
        else => null,
    };
}

fn isSentinel(data: ast.NodeData) bool {
    if (data.isStatement() or data.isDeclaration()) return true;
    return switch (data) {
        .call_expression,
        .class,
        .function,
        .member_expression,
        .new_expression,
        .yield_expression,
        => true,
        else => false,
    };
}

fn containsDynamicExpression(tree: *const ast.Tree, root: ast.NodeIndex) bool {
    var scanner = DynamicExpressionScanner{};
    var subtree = tree.*;
    subtree.root = root;
    traverser.basic.traverse(DynamicExpressionScanner, &subtree, &scanner) catch return true;
    return scanner.found;
}

const DynamicExpressionScanner = struct {
    found: bool = false,

    pub fn enter_node(
        self: *DynamicExpressionScanner,
        data: ast.NodeData,
        _: ast.NodeIndex,
        _: *traverser.basic.Ctx,
    ) traverser.Action {
        switch (data) {
            .call_expression,
            .member_expression,
            .new_expression,
            .tagged_template_expression,
            .yield_expression,
            => {
                self.found = true;
                return .stop;
            },
            .arrow_function_expression => return .skip,
            .function => |function| {
                if (function.type == .function_expression or function.type == .ts_empty_body_function_expression) return .skip;
            },
            .class => |class_node| {
                if (class_node.type == .class_expression) return .skip;
            },
            else => {},
        }
        return .proceed;
    }
};

fn report(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    condition: Condition,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(condition.node),
        "'{s}' is not modified in this loop.",
        .{tree.string(condition.name)},
    );
}

test "recognizes dynamic groups" {
    var tree = try parser.parse(std.testing.allocator, "var foo, obj; while (foo === obj.bar) {}", .{});
    defer tree.deinit();

    var scanner = DynamicExpressionScanner{};
    try traverser.basic.traverse(DynamicExpressionScanner, &tree, &scanner);
    try std.testing.expect(scanner.found);
}
