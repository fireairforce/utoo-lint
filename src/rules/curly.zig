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
    try checkBodyWithOptions(allocator, diagnostics, tree, statement.consequent, options);

    if (statement.alternate == .null) return;
    if (tree.data(statement.alternate) == .if_statement) return;

    try checkBodyWithOptions(allocator, diagnostics, tree, statement.alternate, options);
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
    if (body == .null) return;
    switch (tree.data(body)) {
        .block_statement => |block| {
            if (options.style != .multi) return;
            if (!isUnnecessaryMultiBlock(tree, block)) return;

            try core.addDiagnostic(
                allocator,
                diagnostics,
                .warning,
                id,
                "Unnecessary block statement.",
                tree.span(body),
            );
            return;
        },
        else => {},
    }

    if (options.style == .multi_line or options.style == .multi) {
        if (!isMultiLineBody(tree, body)) return;
    }

    try addExpectedBlockDiagnostic(
        allocator,
        diagnostics,
        tree,
        body,
    );
}

fn addExpectedBlockDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.NodeIndex,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Expected a block statement.",
        tree.span(body),
    );
}

fn isUnnecessaryMultiBlock(tree: *const ast.Tree, block: ast.BlockStatement) bool {
    if (block.body.len != 1) return false;
    const statements = tree.extra(block.body);
    return !hasBlockScopedDeclaration(tree, statements[0]);
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
