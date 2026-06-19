const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "max-depth";

pub const Options = struct {
    max: usize = 4,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    path: *const traverser.NodePath,
    options: Options,
) Allocator.Error!void {
    const depth = nestingDepth(tree, path);
    if (depth <= options.max) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Blocks are nested too deeply ({d}). Maximum allowed is {d}.",
        .{ depth, options.max },
    );
}

fn nestingDepth(tree: *const ast.Tree, path: *const traverser.NodePath) usize {
    var depth: usize = 0;
    var child: ast.NodeIndex = .null;
    var it = path.ancestors();

    while (it.next()) |index| {
        const data = tree.data(index);
        switch (data) {
            .program,
            .function,
            .function_body,
            .arrow_function_expression,
            .static_block,
            => break,
            .if_statement => |statement| {
                if (!isElseIfAncestor(tree, statement, child)) depth += 1;
            },
            .for_statement,
            .for_in_statement,
            .for_of_statement,
            .while_statement,
            .do_while_statement,
            .switch_statement,
            .try_statement,
            .with_statement,
            => depth += 1,
            else => {},
        }
        child = index;
    }

    return depth;
}

fn isElseIfAncestor(tree: *const ast.Tree, statement: ast.IfStatement, child: ast.NodeIndex) bool {
    if (child == .null or statement.alternate != child) return false;
    return switch (tree.data(child)) {
        .if_statement => true,
        else => false,
    };
}
