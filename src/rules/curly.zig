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
            if (options.style != .multi and options.style != .multi_or_nest) return;
            if (!isUnnecessaryBlock(tree, block, options.style)) return;

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
