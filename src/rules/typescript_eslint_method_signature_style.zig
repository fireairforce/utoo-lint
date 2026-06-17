const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = @import("std").mem.Allocator;

pub const id = "@typescript-eslint/method-signature-style";

pub fn checkMethodSignature(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    signature: ast.TSMethodSignature,
    index: ast.NodeIndex,
    style: core.TypescriptEslintMethodSignatureStyle,
) Allocator.Error!void {
    if (style != .property) return;
    if (signature.kind != .method) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Shorthand method signature is forbidden. Use a function property instead.",
        tree.span(index),
    );
}

pub fn checkPropertySignature(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    signature: ast.TSPropertySignature,
    index: ast.NodeIndex,
    style: core.TypescriptEslintMethodSignatureStyle,
) Allocator.Error!void {
    if (style != .method) return;
    if (!isFunctionPropertySignature(tree, signature)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Function property signature is forbidden. Use a method signature instead.",
        tree.span(index),
    );
}

fn isFunctionPropertySignature(tree: *const ast.Tree, signature: ast.TSPropertySignature) bool {
    if (signature.type_annotation == .null) return false;

    const type_index = switch (tree.data(signature.type_annotation)) {
        .ts_type_annotation => |annotation| annotation.type_annotation,
        else => return false,
    };

    return switch (tree.data(type_index)) {
        .ts_function_type => true,
        else => false,
    };
}
