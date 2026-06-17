const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-labels";

pub const Options = struct {
    allow_loop: bool = false,
    allow_switch: bool = false,
};

pub fn checkLabeledStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.LabeledStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkLabeledStatementWithOptions(allocator, diagnostics, tree, statement, index, .{});
}

pub fn checkLabeledStatementWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.LabeledStatement,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (labelBodyAllowed(tree, statement.body, options)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Labels are not allowed.",
        tree.span(index),
    );
}

pub fn checkBreakStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.BreakStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkBreakStatementWithOptions(allocator, diagnostics, tree, statement, index, null, .{});
}

pub fn checkBreakStatementWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.BreakStatement,
    index: ast.NodeIndex,
    path: ?*const traverser.NodePath,
    options: Options,
) Allocator.Error!void {
    if (statement.label == .null) return;
    if (labelTargetAllowed(tree, statement.label, path, options)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected label in break statement.",
        tree.span(index),
    );
}

pub fn checkContinueStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ContinueStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkContinueStatementWithOptions(allocator, diagnostics, tree, statement, index, null, .{});
}

pub fn checkContinueStatementWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ContinueStatement,
    index: ast.NodeIndex,
    path: ?*const traverser.NodePath,
    options: Options,
) Allocator.Error!void {
    if (statement.label == .null) return;
    if (labelTargetAllowed(tree, statement.label, path, .{
        .allow_loop = options.allow_loop,
        .allow_switch = false,
    })) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected label in continue statement.",
        tree.span(index),
    );
}

fn labelTargetAllowed(
    tree: *const ast.Tree,
    label_index: ast.NodeIndex,
    path: ?*const traverser.NodePath,
    options: Options,
) bool {
    const node_path = path orelse return false;
    const expected = labelName(tree, label_index) orelse return false;

    var depth: usize = 1;
    while (node_path.ancestor(depth)) |ancestor| : (depth += 1) {
        const labeled = switch (tree.data(ancestor)) {
            .labeled_statement => |statement| statement,
            else => continue,
        };
        const name = labelName(tree, labeled.label) orelse continue;
        if (!std.mem.eql(u8, name, expected)) continue;

        return labelBodyAllowed(tree, labeled.body, options);
    }
    return false;
}

fn labelBodyAllowed(tree: *const ast.Tree, body_index: ast.NodeIndex, options: Options) bool {
    if (body_index == .null) return false;

    return switch (tree.data(body_index)) {
        .labeled_statement => |statement| labelBodyAllowed(tree, statement.body, options),
        .for_statement,
        .for_in_statement,
        .for_of_statement,
        .while_statement,
        .do_while_statement,
        => options.allow_loop,
        .switch_statement => options.allow_switch,
        else => false,
    };
}

fn labelName(tree: *const ast.Tree, label_index: ast.NodeIndex) ?[]const u8 {
    if (label_index == .null) return null;
    return switch (tree.data(label_index)) {
        .label_identifier => |label| tree.string(label.name),
        else => null,
    };
}
