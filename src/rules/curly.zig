const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "curly";

pub const Options = struct {
    style: core.CurlyStyle = .all,
};

pub fn checkIfStatement(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.IfStatement,
) Allocator.Error!void {
    try checkIfStatementWithOptions(allocator, diagnostics, tree, statement, .{});
}

pub fn checkIfStatementWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.IfStatement,
    options: Options,
) Allocator.Error!void {
    try checkBodyWithContext(
        allocator,
        diagnostics,
        tree,
        statement.consequent,
        options,
        statement.alternate != .null,
    );

    if (statement.alternate == .null) return;
    if (tree.data(statement.alternate) == .if_statement) return;

    try checkBodyWithContext(allocator, diagnostics, tree, statement.alternate, options, false);
}

pub fn checkBody(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.NodeIndex,
) Allocator.Error!void {
    return checkBodyWithOptions(allocator, diagnostics, tree, body, .{});
}

pub fn checkBodyWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    return checkBodyWithContext(allocator, diagnostics, tree, body, options, false);
}

fn checkBodyWithContext(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.NodeIndex,
    options: Options,
    protect_dangling_else: bool,
) Allocator.Error!void {
    if (body == .null) return;
    switch (tree.data(body)) {
        .block_statement => |block| {
            if (options.style != .multi and options.style != .multi_or_nest) return;
            if (!isUnnecessaryBlock(tree, block, options.style)) return;

            if (try unnecessaryBlockReplacement(allocator, tree, body, block, protect_dangling_else)) |replacement| {
                defer allocator.free(replacement);
                const span = tree.span(body);
                try core.addDiagnosticWithFix(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    "Unnecessary block statement.",
                    span,
                    .{ .span = span, .replacement = replacement },
                );
            } else {
                try core.addDiagnostic(
                    allocator,
                    diagnostics,
                    .warning,
                    id,
                    "Unnecessary block statement.",
                    tree.span(body),
                );
            }
            return;
        },
        else => {},
    }

    switch (options.style) {
        .all => {},
        .multi_line, .multi => {
            if (!isMultiLineBody(tree, body)) return;
        },
        .multi_or_nest => {
            if (!isMultiLineBody(tree, body) and !isControlStatement(tree, body)) return;
        },
    }

    try addExpectedBlockDiagnostic(
        allocator,
        diagnostics,
        tree,
        body,
        switch (options.style) {
            .all, .multi_line => true,
            .multi => false,
            .multi_or_nest => isControlStatement(tree, body),
        },
    );
}

fn unnecessaryBlockReplacement(
    allocator: Allocator,
    tree: *const ast.Tree,
    body: ast.NodeIndex,
    block: ast.BlockStatement,
    protect_dangling_else: bool,
) Allocator.Error!?[]u8 {
    const statements = tree.extra(block.body);
    const statement = statements[0];

    if (protect_dangling_else) {
        switch (tree.data(statement)) {
            .if_statement => |nested| if (nested.alternate == .null) return null,
            else => {},
        }
    }

    const block_span = tree.span(body);
    if (block_span.end <= block_span.start + 1 or
        tree.source[block_span.start] != '{' or
        tree.source[block_span.end - 1] != '}') return null;
    if (!isSafeWithoutBlock(tree, tree.span(statement), block_span)) return null;

    const inner = tree.source[block_span.start + 1 .. block_span.end - 1];
    const prefix = if (needsLeadingSpace(tree.source, block_span.start, inner)) " " else "";
    const suffix = if (needsTrailingSpace(tree.source, block_span.end, inner)) " " else "";
    return try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ prefix, inner, suffix });
}

fn isSafeWithoutBlock(tree: *const ast.Tree, statement_span: ast.Span, block_span: ast.Span) bool {
    if (previousCodeOffset(tree, statement_span.end, statement_span.start)) |offset| {
        if (tree.source[offset] == ';') return true;
    }

    const next = nextCodeOffset(tree, block_span.end) orelse return true;
    if (!containsLineTerminator(tree.source[block_span.end..next])) return false;

    return switch (tree.source[next]) {
        '(', '[', '/', '`', '+', '-' => false,
        else => true,
    };
}

fn nextCodeOffset(tree: *const ast.Tree, start: u32) ?usize {
    var cursor: usize = start;
    while (cursor < tree.source.len) {
        if (std.ascii.isWhitespace(tree.source[cursor])) {
            cursor += 1;
            continue;
        }
        if (commentAt(tree, @intCast(cursor))) |comment| {
            cursor = comment.span.end;
            continue;
        }
        return cursor;
    }
    return null;
}

fn previousCodeOffset(tree: *const ast.Tree, end: u32, start: u32) ?usize {
    var cursor: usize = end;
    while (cursor > start) {
        while (cursor > start and std.ascii.isWhitespace(tree.source[cursor - 1])) cursor -= 1;
        if (cursor == start) return null;

        var skipped_comment = false;
        for (tree.comments) |comment| {
            if (comment.span.end != cursor or comment.span.start < start) continue;
            cursor = comment.span.start;
            skipped_comment = true;
            break;
        }
        if (skipped_comment) continue;
        return cursor - 1;
    }
    return null;
}

fn commentAt(tree: *const ast.Tree, offset: u32) ?ast.Comment {
    for (tree.comments) |comment| {
        if (comment.span.end <= offset) continue;
        if (comment.span.start > offset) break;
        return comment;
    }
    return null;
}

fn needsLeadingSpace(source: []const u8, block_start: u32, inner: []const u8) bool {
    return block_start > 0 and inner.len > 0 and
        isIdentifierByte(source[block_start - 1]) and isIdentifierByte(inner[0]);
}

fn needsTrailingSpace(source: []const u8, block_end: u32, inner: []const u8) bool {
    return block_end < source.len and inner.len > 0 and
        isIdentifierByte(inner[inner.len - 1]) and isIdentifierByte(source[block_end]);
}

fn isIdentifierByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '$';
}

fn addExpectedBlockDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.NodeIndex,
    allow_fix: bool,
) Allocator.Error!void {
    const span = tree.span(body);
    if (!allow_fix) {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Expected a block statement.",
            span,
        );
        return;
    }

    const replacement = try std.fmt.allocPrint(allocator, "{{{s}}}", .{tree.source[span.start..span.end]});
    defer allocator.free(replacement);

    try core.addDiagnosticWithFix(
        allocator,
        diagnostics,
        .warning,
        id,
        "Expected a block statement.",
        span,
        .{ .span = span, .replacement = replacement },
    );
}

fn isUnnecessaryBlock(tree: *const ast.Tree, block: ast.BlockStatement, style: core.CurlyStyle) bool {
    if (block.body.len != 1) return false;
    const statements = tree.extra(block.body);
    if (style == .multi_or_nest and isControlStatement(tree, statements[0])) return false;
    return !hasBlockScopedDeclaration(tree, statements[0]);
}

fn isControlStatement(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .if_statement,
        .while_statement,
        .do_while_statement,
        .for_statement,
        .for_in_statement,
        .for_of_statement,
        => true,
        else => false,
    };
}

fn hasBlockScopedDeclaration(tree: *const ast.Tree, statement: ast.NodeIndex) bool {
    return switch (tree.data(statement)) {
        .variable_declaration => |declaration| switch (declaration.kind) {
            .@"var" => false,
            .let, .@"const", .using, .await_using => true,
        },
        .class => |class| class.type == .class_declaration,
        .function => |function| function.type == .function_declaration,
        else => false,
    };
}

fn isMultiLineBody(tree: *const ast.Tree, body: ast.NodeIndex) bool {
    const span = tree.span(body);
    if (containsLineTerminator(tree.source[span.start..span.end])) return true;
    return hasLineTerminatorBeforeBody(tree.source, span.start);
}

fn hasLineTerminatorBeforeBody(source: []const u8, body_start: usize) bool {
    var index = body_start;
    while (index > 0) {
        index -= 1;
        switch (source[index]) {
            ' ', '\t' => continue,
            '\n', '\r' => return true,
            else => return false,
        }
    }
    return false;
}

fn containsLineTerminator(source: []const u8) bool {
    for (source) |char| {
        if (char == '\n' or char == '\r') return true;
    }
    return false;
}
