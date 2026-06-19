const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-unreachable-loop";

pub const LoopKind = enum {
    while_statement,
    do_while_statement,
    for_statement,
    for_in_statement,
    for_of_statement,
};

pub const Options = struct {
    ignore_while: bool = false,
    ignore_do_while: bool = false,
    ignore_for: bool = false,
    ignore_for_in: bool = false,
    ignore_for_of: bool = false,

    fn ignores(self: Options, kind: LoopKind) bool {
        return switch (kind) {
            .while_statement => self.ignore_while,
            .do_while_statement => self.ignore_do_while,
            .for_statement => self.ignore_for,
            .for_in_statement => self.ignore_for_in,
            .for_of_statement => self.ignore_for_of,
        };
    }
};

pub fn checkWhileStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.WhileStatement,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    try checkLoop(allocator, diagnostics, tree, statement.body, index, .while_statement, options);
}

pub fn checkDoWhileStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.DoWhileStatement,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    try checkLoop(allocator, diagnostics, tree, statement.body, index, .do_while_statement, options);
}

pub fn checkForStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ForStatement,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    try checkLoop(allocator, diagnostics, tree, statement.body, index, .for_statement, options);
}

pub fn checkForInStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ForInStatement,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    try checkLoop(allocator, diagnostics, tree, statement.body, index, .for_in_statement, options);
}

pub fn checkForOfStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ForOfStatement,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    try checkLoop(allocator, diagnostics, tree, statement.body, index, .for_of_statement, options);
}

fn checkLoop(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.NodeIndex,
    loop_index: ast.NodeIndex,
    kind: LoopKind,
    options: Options,
) Allocator.Error!void {
    if (options.ignores(kind)) return;
    if (!statementExitsLoop(tree, body, .{ .bare_break_exits_loop = true })) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "This loop will never iterate more than once.",
        tree.span(loop_index),
    );
}

const ExitContext = struct {
    bare_break_exits_loop: bool,
};

fn statementExitsLoop(tree: *const ast.Tree, index: ast.NodeIndex, ctx: ExitContext) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .return_statement,
        .throw_statement,
        => true,
        .break_statement => |statement| statement.label == .null and ctx.bare_break_exits_loop,
        .block_statement => |block| statementRangeExitsLoop(tree, block.body, ctx),
        .if_statement => |statement| statement.alternate != .null and
            statementExitsLoop(tree, statement.consequent, ctx) and
            statementExitsLoop(tree, statement.alternate, ctx),
        .labeled_statement => |statement| statementExitsLoop(tree, statement.body, ctx),
        .switch_statement => |statement| switchExitsLoop(tree, statement),
        .try_statement => |statement| tryExitsLoop(tree, statement, ctx),
        .catch_clause => |clause| statementExitsLoop(tree, clause.body, ctx),
        .while_statement,
        .do_while_statement,
        .for_statement,
        .for_in_statement,
        .for_of_statement,
        .function,
        .arrow_function_expression,
        .class,
        => false,
        else => false,
    };
}

fn statementRangeExitsLoop(tree: *const ast.Tree, range: ast.IndexRange, ctx: ExitContext) bool {
    for (tree.extra(range)) |statement| {
        if (statementExitsLoop(tree, statement, ctx)) return true;
    }
    return false;
}

fn switchExitsLoop(tree: *const ast.Tree, statement: ast.SwitchStatement) bool {
    var has_default = false;
    const switch_ctx = ExitContext{ .bare_break_exits_loop = false };

    for (tree.extra(statement.cases)) |case_index| {
        const case = switch (tree.data(case_index)) {
            .switch_case => |case| case,
            else => continue,
        };
        if (case.@"test" == .null) has_default = true;
        if (!statementRangeExitsLoop(tree, case.consequent, switch_ctx)) return false;
    }

    return has_default and statement.cases.len > 0;
}

fn tryExitsLoop(tree: *const ast.Tree, statement: ast.TryStatement, ctx: ExitContext) bool {
    if (statement.finalizer != .null and statementExitsLoop(tree, statement.finalizer, ctx)) return true;
    if (!statementExitsLoop(tree, statement.block, ctx)) return false;
    if (statement.handler == .null) return true;
    return statementExitsLoop(tree, statement.handler, ctx);
}
