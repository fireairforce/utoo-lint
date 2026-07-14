const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const Policy = struct {
    allow_optional: bool = false,
    minimum_non_spread_when_nonempty: usize = 2,
};

pub fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    callee: ast.NodeIndex,
    arguments: ast.IndexRange,
    optional: bool,
    prefix_semicolon: bool,
    policy: Policy,
    severity: core.Severity,
    rule_id: []const u8,
    message: []const u8,
) Allocator.Error!void {
    const span = tree.span(index);
    if (!canAutofix(tree, span, callee, arguments, optional, policy)) {
        try core.addDiagnostic(allocator, diagnostics, severity, rule_id, message, span);
        return;
    }

    const arguments_text = argumentsText(tree, span, callee);
    const replacement = try std.fmt.allocPrint(
        allocator,
        "{s}[{s}]",
        .{ if (prefix_semicolon) ";" else "", arguments_text },
    );
    defer allocator.free(replacement);

    try core.addDiagnosticWithFix(
        allocator,
        diagnostics,
        severity,
        rule_id,
        message,
        span,
        .{ .span = span, .replacement = replacement },
    );
}

pub fn needsAsiGuard(tree: *const ast.Tree, index: ast.NodeIndex, path: anytype) bool {
    const start = tree.span(index).start;
    var depth: usize = 1;

    while (path.ancestor(depth)) |ancestor_index| : (depth += 1) {
        if (tree.span(ancestor_index).start != start) return false;
        if (tree.data(ancestor_index) != .expression_statement) continue;

        const parent_index = path.ancestor(depth + 1) orelse return false;
        if (!isStatementList(tree, parent_index)) return false;
        return needsGuardAfterPreviousToken(tree, start);
    }

    return false;
}

fn canAutofix(
    tree: *const ast.Tree,
    span: ast.Span,
    callee: ast.NodeIndex,
    arguments: ast.IndexRange,
    optional: bool,
    policy: Policy,
) bool {
    if (optional and !policy.allow_optional) return false;
    if (arguments.len > 0 and nonSpreadCount(tree, arguments) < policy.minimum_non_spread_when_nonempty) return false;

    const opening_parenthesis = openingParenthesis(tree, span, callee);
    const header_end = opening_parenthesis orelse span.end;
    for (tree.comments) |comment| {
        if (comment.span.start >= span.start and comment.span.end <= header_end) return false;
    }

    return true;
}

fn nonSpreadCount(tree: *const ast.Tree, arguments: ast.IndexRange) usize {
    var count: usize = 0;
    for (tree.extra(arguments)) |argument| {
        if (tree.data(argument) != .spread_element) count += 1;
    }
    return count;
}

fn argumentsText(tree: *const ast.Tree, span: ast.Span, callee: ast.NodeIndex) []const u8 {
    if (span.end == 0 or tree.source[span.end - 1] != ')') return "";
    const opening = openingParenthesis(tree, span, callee) orelse return "";
    return tree.source[opening + 1 .. span.end - 1];
}

fn openingParenthesis(tree: *const ast.Tree, span: ast.Span, callee: ast.NodeIndex) ?u32 {
    const search_start = tree.span(callee).end;
    if (search_start >= span.end) return null;
    const offset = std.mem.indexOfScalar(u8, tree.source[search_start..span.end], '(') orelse return null;
    return search_start + @as(u32, @intCast(offset));
}

fn isStatementList(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .program,
        .function_body,
        .block_statement,
        .static_block,
        .switch_case,
        => true,
        else => false,
    };
}

fn needsGuardAfterPreviousToken(tree: *const ast.Tree, start: u32) bool {
    const previous = previousSignificantByte(tree, start) orelse return false;
    const char = tree.source[previous];
    if (char == ';' or char == '{' or char == ':') return false;

    if (previous > 0) {
        const pair = tree.source[previous - 1 .. previous + 1];
        if (std.mem.eql(u8, pair, "++") or
            std.mem.eql(u8, pair, "--") or
            std.mem.eql(u8, pair, "=>")) return false;
    }

    return true;
}

fn previousSignificantByte(tree: *const ast.Tree, start: u32) ?usize {
    var cursor: usize = start;

    while (cursor > 0) {
        while (cursor > 0 and std.ascii.isWhitespace(tree.source[cursor - 1])) cursor -= 1;
        if (cursor == 0) return null;

        var skipped_comment = false;
        for (tree.comments) |comment| {
            if (comment.span.end != cursor) continue;
            cursor = comment.span.start;
            skipped_comment = true;
            break;
        }
        if (skipped_comment) continue;

        return cursor - 1;
    }

    return null;
}
