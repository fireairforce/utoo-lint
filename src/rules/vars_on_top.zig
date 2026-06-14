const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = @import("std").mem.Allocator;

pub const id = "vars-on-top";

const Scope = struct {
    index: ast.NodeIndex,
    is_function: bool,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.VariableDeclaration,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    if (declaration.kind != .@"var") return;

    const scope = nearestScope(tree, ctx) orelse return;
    const statement = statementForDeclaration(tree, index, ctx);
    if (statement != .null and isLeadingVarStatement(tree, scope.index, statement)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        if (scope.is_function)
            "All 'var' declarations must be at the top of the function scope."
        else
            "All 'var' declarations must be at the top of the program scope.",
        tree.span(index),
    );
}

fn statementForDeclaration(tree: *const ast.Tree, index: ast.NodeIndex, ctx: *traverser.basic.Ctx) ast.NodeIndex {
    const parent = ctx.path.ancestor(1) orelse return .null;
    return switch (tree.data(parent)) {
        .program, .function_body => index,
        .export_named_declaration, .export_default_declaration => parent,
        else => .null,
    };
}

fn nearestScope(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) ?Scope {
    var depth: usize = 1;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .function_body => return .{ .index = ancestor, .is_function = true },
            .program => return .{ .index = ancestor, .is_function = false },
            else => {},
        }
    }

    return null;
}

fn isLeadingVarStatement(tree: *const ast.Tree, scope_index: ast.NodeIndex, statement: ast.NodeIndex) bool {
    const body = switch (tree.data(scope_index)) {
        .program => |program| program.body,
        .function_body => |function_body| function_body.body,
        else => return false,
    };

    var seen_non_leading_statement = false;
    for (tree.extra(body)) |child| {
        if (child == statement) return !seen_non_leading_statement;
        if (!isLeadingStatement(tree, child)) {
            seen_non_leading_statement = true;
        }
    }

    return false;
}

fn isLeadingStatement(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .directive => true,
        .variable_declaration => |declaration| declaration.kind == .@"var",
        .export_named_declaration => |declaration| isVarDeclaration(tree, declaration.declaration),
        .export_default_declaration => |declaration| isVarDeclaration(tree, declaration.declaration),
        else => false,
    };
}

fn isVarDeclaration(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;
    return switch (tree.data(index)) {
        .variable_declaration => |declaration| declaration.kind == .@"var",
        else => false,
    };
}
