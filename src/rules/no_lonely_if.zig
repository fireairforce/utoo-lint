const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const std = @import("std");
const Allocator = std.mem.Allocator;

pub const id = "no-lonely-if";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.IfStatement,
) Allocator.Error!void {
    const lonely_if = lonelyIf(tree, statement) orelse return;

    const block_span = tree.span(lonely_if.block);
    const child_span = tree.span(lonely_if.child);
    if (hasNonWhitespace(tree.source[block_span.start + 1 .. child_span.start]) or
        hasNonWhitespace(tree.source[child_span.end .. block_span.end - 1]) or
        removingBracesChangesAsi(tree, lonely_if))
    {
        return core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Unexpected if as the only statement in an else block.",
            child_span,
        );
    }

    const prefix = if (block_span.start >= 4 and
        std.mem.eql(u8, tree.source[block_span.start - 4 .. block_span.start], "else")) " " else "";
    const replacement = try std.fmt.allocPrint(
        allocator,
        "{s}{s}",
        .{ prefix, tree.source[child_span.start..child_span.end] },
    );
    defer allocator.free(replacement);

    try core.addDiagnosticWithFix(
        allocator,
        diagnostics,
        .warning,
        id,
        "Unexpected if as the only statement in an else block.",
        child_span,
        .{ .span = block_span, .replacement = replacement },
    );
}

fn hasNonWhitespace(source: []const u8) bool {
    for (source) |byte| {
        if (!std.ascii.isWhitespace(byte)) return true;
    }
    return false;
}

fn removingBracesChangesAsi(tree: *const ast.Tree, lonely_if: LonelyIf) bool {
    const statement = tree.data(lonely_if.child).if_statement;
    if (tree.data(statement.consequent) == .block_statement) return false;

    const consequent_span = tree.span(statement.consequent);
    if (consequent_span.end > consequent_span.start and tree.source[consequent_span.end - 1] == ';') return false;

    const block_end = tree.span(lonely_if.block).end;
    const next_offset = nextCodeOffset(tree, block_end) orelse return false;
    if (std.mem.indexOfAny(u8, tree.source[consequent_span.end..next_offset], "\r\n") == null) return true;

    const next_byte = tree.source[next_offset];
    if (std.mem.indexOfScalar(u8, "([/+`-", next_byte) != null) return true;

    if (consequent_span.end >= consequent_span.start + 2) {
        const ending = tree.source[consequent_span.end - 2 .. consequent_span.end];
        if (std.mem.eql(u8, ending, "++") or std.mem.eql(u8, ending, "--")) return true;
    }
    return false;
}

const LonelyIf = struct {
    block: ast.NodeIndex,
    child: ast.NodeIndex,
};

fn lonelyIf(tree: *const ast.Tree, statement: ast.IfStatement) ?LonelyIf {
    if (statement.alternate == .null) return null;

    const block = switch (tree.data(statement.alternate)) {
        .block_statement => |block| block,
        else => return null,
    };
    if (block.body.len != 1) return null;

    const child = tree.extra(block.body)[0];
    if (tree.data(child) != .if_statement) return null;
    if (hasUnsafeIf(tree, child) and isFollowedByElse(tree, statement.alternate)) return null;
    return .{ .block = statement.alternate, .child = child };
}

fn hasUnsafeIf(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .if_statement => |statement| statement.alternate == .null or hasUnsafeIf(tree, statement.alternate),
        .for_statement => |statement| hasUnsafeIf(tree, statement.body),
        .for_in_statement => |statement| hasUnsafeIf(tree, statement.body),
        .for_of_statement => |statement| hasUnsafeIf(tree, statement.body),
        .labeled_statement => |statement| hasUnsafeIf(tree, statement.body),
        .with_statement => |statement| hasUnsafeIf(tree, statement.body),
        .while_statement => |statement| hasUnsafeIf(tree, statement.body),
        else => false,
    };
}

fn isFollowedByElse(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const offset = nextCodeOffset(tree, tree.span(index).end) orelse return false;
    return offset + "else".len <= tree.source.len and
        std.mem.eql(u8, tree.source[offset .. offset + "else".len], "else");
}

fn nextCodeOffset(tree: *const ast.Tree, start: u32) ?usize {
    var cursor: usize = start;
    while (cursor < tree.source.len) {
        if (std.ascii.isWhitespace(tree.source[cursor])) {
            cursor += 1;
            continue;
        }
        var skipped_comment = false;
        for (tree.comments) |comment| {
            if (comment.span.start > cursor) break;
            if (comment.span.start == cursor) {
                cursor = comment.span.end;
                skipped_comment = true;
                break;
            }
        }
        if (!skipped_comment) return cursor;
    }
    return null;
}
