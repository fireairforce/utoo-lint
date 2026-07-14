const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-extra-label";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.LabeledStatement,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const label_name = labelName(tree, statement.label) orelse return;
    try reportRedundantLoopLabelReferences(allocator, diagnostics, tree, statement.body, label_name);
    if (containsLabelReference(tree, statement.body, label_name)) return;

    const fix_span = ast.Span{
        .start = tree.span(statement.label).start,
        .end = tree.span(statement.body).start,
    };
    if (hasCommentBetween(tree, fix_span.start, fix_span.end)) {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "This label is unnecessary.",
            tree.span(index),
        );
    } else {
        try core.addDiagnosticWithFix(
            allocator,
            diagnostics,
            .warning,
            id,
            "This label is unnecessary.",
            tree.span(index),
            .{ .span = fix_span, .replacement = "" },
        );
    }
}

fn reportRedundantLoopLabelReferences(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    label_name: []const u8,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(index)) {
        .for_statement => |statement| try reportRedundantLoopBodyReferences(allocator, diagnostics, tree, statement.body, label_name),
        .for_in_statement => |statement| try reportRedundantLoopBodyReferences(allocator, diagnostics, tree, statement.body, label_name),
        .for_of_statement => |statement| try reportRedundantLoopBodyReferences(allocator, diagnostics, tree, statement.body, label_name),
        .while_statement => |statement| try reportRedundantLoopBodyReferences(allocator, diagnostics, tree, statement.body, label_name),
        .do_while_statement => |statement| try reportRedundantLoopBodyReferences(allocator, diagnostics, tree, statement.body, label_name),
        else => {},
    }
}

fn reportRedundantLoopBodyReferences(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    label_name: []const u8,
) Allocator.Error!void {
    if (index == .null) return;

    switch (tree.data(index)) {
        .break_statement => |statement| {
            if (sameLabel(tree, statement.label, label_name)) {
                try addRedundantReferenceDiagnostic(allocator, diagnostics, tree, index, statement.label, label_name);
            }
        },
        .continue_statement => |statement| {
            if (sameLabel(tree, statement.label, label_name)) {
                try addRedundantReferenceDiagnostic(allocator, diagnostics, tree, index, statement.label, label_name);
            }
        },
        .block_statement => |block| try reportRedundantReferencesInRange(allocator, diagnostics, tree, block.body, label_name),
        .static_block => |block| try reportRedundantReferencesInRange(allocator, diagnostics, tree, block.body, label_name),
        .if_statement => |statement| {
            try reportRedundantLoopBodyReferences(allocator, diagnostics, tree, statement.consequent, label_name);
            try reportRedundantLoopBodyReferences(allocator, diagnostics, tree, statement.alternate, label_name);
        },
        .try_statement => |statement| {
            try reportRedundantLoopBodyReferences(allocator, diagnostics, tree, statement.block, label_name);
            if (statement.handler != .null) {
                const handler = switch (tree.data(statement.handler)) {
                    .catch_clause => |handler| handler,
                    else => return,
                };
                try reportRedundantLoopBodyReferences(allocator, diagnostics, tree, handler.body, label_name);
            }
            try reportRedundantLoopBodyReferences(allocator, diagnostics, tree, statement.finalizer, label_name);
        },
        .labeled_statement => |statement| try reportRedundantLoopBodyReferences(allocator, diagnostics, tree, statement.body, label_name),
        .function,
        .arrow_function_expression,
        .class,
        .for_statement,
        .for_in_statement,
        .for_of_statement,
        .while_statement,
        .do_while_statement,
        .switch_statement,
        => {},
        else => {},
    }
}

fn reportRedundantReferencesInRange(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    range: ast.IndexRange,
    label_name: []const u8,
) Allocator.Error!void {
    for (tree.extra(range)) |child| {
        try reportRedundantLoopBodyReferences(allocator, diagnostics, tree, child, label_name);
    }
}

fn addRedundantReferenceDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.NodeIndex,
    label: ast.NodeIndex,
    label_name: []const u8,
) Allocator.Error!void {
    const statement_span = tree.span(statement);
    const keyword_end = statement_span.start + switch (tree.data(statement)) {
        .break_statement => @as(u32, "break".len),
        .continue_statement => @as(u32, "continue".len),
        else => return,
    };
    const message = try std.fmt.allocPrint(allocator, "This label '{s}' is unnecessary.", .{label_name});
    defer allocator.free(message);
    const label_span = tree.span(label);

    if (hasCommentBetween(tree, keyword_end, label_span.end)) {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            message,
            label_span,
        );
        return;
    }

    try core.addDiagnosticWithFix(
        allocator,
        diagnostics,
        .warning,
        id,
        message,
        label_span,
        .{
            .span = .{ .start = keyword_end, .end = label_span.end },
            .replacement = "",
        },
    );
}

fn hasCommentBetween(tree: *const ast.Tree, start: u32, end: u32) bool {
    for (tree.comments) |comment| {
        if (comment.span.start < end and comment.span.end > start) return true;
    }
    return false;
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
        .labeled_statement => |statement| containsLabelReference(tree, statement.body, label_name),
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
