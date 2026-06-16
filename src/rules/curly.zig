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
    if (tree.data(body) == .block_statement) return;
    if (options.style == .multi_line and !isMultiLineBody(tree, body)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Expected a block statement.",
        tree.span(body),
    );
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
