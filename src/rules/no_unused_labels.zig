const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-unused-labels";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.LabeledStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const label_name = labelName(tree, statement.label) orelse return;
    if (containsLabelReference(tree, statement.body, label_name)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unused label.",
        tree.span(index),
    );
}

fn labelName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .label_identifier => |label| tree.string(label.name),
        else => null,
    };
}

fn containsLabelReference(tree: *const ast.Tree, index: ast.NodeIndex, label_name: []const u8) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .break_statement => |statement| sameLabel(tree, statement.label, label_name),
        .continue_statement => |statement| sameLabel(tree, statement.label, label_name),
        .block_statement => |block| rangeContainsLabelReference(tree, block.body, label_name),
        .static_block => |block| rangeContainsLabelReference(tree, block.body, label_name),
        .if_statement => |statement| containsLabelReference(tree, statement.consequent, label_name) or
            containsLabelReference(tree, statement.alternate, label_name),
        .switch_statement => |statement| {
            for (tree.extra(statement.cases)) |case_index| {
                const switch_case = switch (tree.data(case_index)) {
                    .switch_case => |switch_case| switch_case,
                    else => continue,
                };
                if (rangeContainsLabelReference(tree, switch_case.consequent, label_name)) return true;
            }
            return false;
        },
        .for_statement => |statement| containsLabelReference(tree, statement.body, label_name),
        .for_in_statement => |statement| containsLabelReference(tree, statement.body, label_name),
        .for_of_statement => |statement| containsLabelReference(tree, statement.body, label_name),
        .while_statement => |statement| containsLabelReference(tree, statement.body, label_name),
        .do_while_statement => |statement| containsLabelReference(tree, statement.body, label_name),
        .with_statement => |statement| containsLabelReference(tree, statement.body, label_name),
        .labeled_statement => |statement| {
            if (sameLabel(tree, statement.label, label_name)) return false;
            return containsLabelReference(tree, statement.body, label_name);
        },
        .try_statement => |statement| {
            if (containsLabelReference(tree, statement.block, label_name)) return true;
            if (statement.handler != .null) {
                const handler = switch (tree.data(statement.handler)) {
                    .catch_clause => |handler| handler,
                    else => return false,
                };
                if (containsLabelReference(tree, handler.body, label_name)) return true;
            }
            return containsLabelReference(tree, statement.finalizer, label_name);
        },
        .function,
        .class,
        => false,
        else => false,
    };
}

fn rangeContainsLabelReference(tree: *const ast.Tree, range: ast.IndexRange, label_name: []const u8) bool {
    for (tree.extra(range)) |child| {
        if (containsLabelReference(tree, child, label_name)) return true;
    }
    return false;
}

fn sameLabel(tree: *const ast.Tree, index: ast.NodeIndex, label_name: []const u8) bool {
    const name = labelName(tree, index) orelse return false;
    return std.mem.eql(u8, name, label_name);
}
