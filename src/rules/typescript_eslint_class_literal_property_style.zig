const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/class-literal-property-style";

pub fn checkMethodDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    method: ast.MethodDefinition,
    index: ast.NodeIndex,
    style: core.TypescriptEslintClassLiteralPropertyStyle,
) Allocator.Error!void {
    if (style != .fields) return;
    if (method.kind != .get) return;
    if (!getterReturnsSingleLiteral(tree, method)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Literals should be exposed using readonly fields.",
        tree.span(index),
    );
}

pub fn checkPropertyDefinition(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    property: ast.PropertyDefinition,
    index: ast.NodeIndex,
    style: core.TypescriptEslintClassLiteralPropertyStyle,
) Allocator.Error!void {
    if (style != .getters) return;
    if (!property.readonly) return;
    if (!isLiteral(tree, property.value)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Literals should be exposed using getters.",
        tree.span(index),
    );
}

fn getterReturnsSingleLiteral(tree: *const ast.Tree, method: ast.MethodDefinition) bool {
    const function = switch (tree.data(method.value)) {
        .function => |function| function,
        else => return false,
    };
    if (function.body == .null) return false;

    const body = switch (tree.data(function.body)) {
        .function_body => |body| body,
        else => return false,
    };

    const statements = tree.extra(body.body);
    if (statements.len != 1) return false;

    const statement = switch (tree.data(statements[0])) {
        .return_statement => |statement| statement,
        else => return false,
    };

    return isLiteral(tree, statement.argument);
}

fn isLiteral(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .string_literal,
        .numeric_literal,
        .bigint_literal,
        .boolean_literal,
        .null_literal,
        .regexp_literal,
        => true,
        .template_literal => |literal| literal.expressions.len == 0,
        else => false,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;
    while (current != .null) {
        switch (tree.data(current)) {
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            .chain_expression => |chain| current = chain.expression,
            else => return current,
        }
    }
    return current;
}
