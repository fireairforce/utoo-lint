const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "no-unreachable";

pub fn checkRange(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    range: ast.IndexRange,
) Allocator.Error!void {
    var is_unreachable = false;

    for (tree.extra(range)) |statement| {
        if (is_unreachable and !isHoistedDeclaration(tree, statement)) {
            try core.addDiagnostic(
                allocator,
                diagnostics,
                .warning,
                id,
                "Unreachable code.",
                tree.span(statement),
            );
        }

        if (alwaysExits(tree, statement)) {
            is_unreachable = true;
        }
    }
}

fn alwaysExits(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(index)) {
        .return_statement,
        .throw_statement,
        .break_statement,
        .continue_statement,
        => true,
        .block_statement => |block| rangeAlwaysExits(tree, block.body),
        .if_statement => |statement| statement.alternate != .null and
            alwaysExits(tree, statement.consequent) and
            alwaysExits(tree, statement.alternate),
        .try_statement => |statement| tryAlwaysExits(tree, statement),
        else => false,
    };
}

fn tryAlwaysExits(tree: *const ast.Tree, statement: ast.TryStatement) bool {
    if (alwaysExits(tree, statement.finalizer)) return true;

    const block_exits = alwaysExits(tree, statement.block);
    if (statement.handler == .null) return block_exits;

    const handler_body = switch (tree.data(statement.handler)) {
        .catch_clause => |handler| handler.body,
        else => return false,
    };
    return block_exits and alwaysExits(tree, handler_body);
}

fn rangeAlwaysExits(tree: *const ast.Tree, range: ast.IndexRange) bool {
    if (range.len == 0) return false;

    const statements = tree.extra(range);
    return alwaysExits(tree, statements[statements.len - 1]);
}

fn isHoistedDeclaration(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    return switch (tree.data(index)) {
        .function => |function| function.type == .function_declaration or function.type == .ts_declare_function,
        .variable_declaration => |declaration| declaration.kind == .@"var" and !hasInitializedDeclarator(tree, declaration),
        else => false,
    };
}

fn hasInitializedDeclarator(tree: *const ast.Tree, declaration: ast.VariableDeclaration) bool {
    for (tree.extra(declaration.declarators)) |declarator_index| {
        const declarator = tree.data(declarator_index).variable_declarator;
        if (declarator.init != .null) return true;
    }
    return false;
}
