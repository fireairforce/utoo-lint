const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "no-useless-return";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.ReturnStatement,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (statement.argument != .null) return;
    if (!isRedundantReturn(tree, index, ctx)) return;

    const span = tree.span(index);
    if (hasStatementListParent(tree, ctx) and !hasReturnComment(tree, span)) {
        try core.addDiagnosticWithFix(
            allocator,
            diagnostics,
            .warning,
            id,
            "Unnecessary return statement.",
            span,
            .{ .span = span, .replacement = "" },
        );
    } else {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Unnecessary return statement.",
            span,
        );
    }
}

fn hasReturnComment(tree: *const ast.Tree, span: ast.Span) bool {
    for (tree.comments) |comment| {
        if (comment.span.start < span.end and comment.span.end > span.start) return true;
    }

    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (start > end or end > tree.source.len) return true;
    if (std.mem.indexOfScalar(u8, tree.source[start..end], ';') != null) return false;

    for (tree.comments) |comment| {
        if (comment.type != .line or comment.span.start < span.end) continue;
        const comment_start: usize = @intCast(comment.span.start);
        if (comment_start > tree.source.len) continue;
        if (std.mem.indexOfScalar(u8, tree.source[end..comment_start], '\n') == null) return true;
    }
    return false;
}

fn hasStatementListParent(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    const parent = ctx.path.ancestor(1) orelse return false;
    return switch (tree.data(parent)) {
        .program,
        .block_statement,
        .function_body,
        .static_block,
        .switch_case,
        => true,
        else => false,
    };
}

fn isRedundantReturn(tree: *const ast.Tree, index: ast.NodeIndex, ctx: *traverser.basic.Ctx) bool {
    var child = index;
    var depth: usize = 1;

    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .function_body => |body| return isLastInRange(tree, child, body.body),
            .block_statement => |block| {
                if (!isLastInRange(tree, child, block.body)) return false;
                child = ancestor;
            },
            .switch_case => |case| {
                if (!isLastInRange(tree, child, case.consequent)) return false;
                child = ancestor;
            },
            .switch_statement => |statement| {
                if (!isLastInRange(tree, child, statement.cases)) return false;
                child = ancestor;
            },
            .if_statement => |statement| {
                if (statement.consequent != child and statement.alternate != child) return false;
                child = ancestor;
            },
            .try_statement => |statement| {
                if (statement.block != child and (statement.handler == .null or statement.handler != child)) return false;
                if (statement.handler == child and statement.finalizer != .null) return false;
                child = ancestor;
            },
            .catch_clause => |clause| {
                if (clause.body != child) return false;
                child = ancestor;
            },
            .while_statement,
            .do_while_statement,
            .for_statement,
            .for_in_statement,
            .for_of_statement,
            => return false,
            .function,
            .arrow_function_expression,
            .program,
            => return false,
            else => child = ancestor,
        }
    }

    return false;
}

fn isLastInRange(tree: *const ast.Tree, index: ast.NodeIndex, range: ast.IndexRange) bool {
    if (range.len == 0) return false;
    const items = tree.extra(range);
    return items[items.len - 1] == index;
}
