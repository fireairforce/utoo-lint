const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/array-type";

pub fn checkTypeReference(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    reference: ast.TSTypeReference,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const name = typeName(tree, reference.type_name) orelse return;
    const readonly = std.mem.eql(u8, name, "ReadonlyArray");
    if (!readonly and !std.mem.eql(u8, name, "Array")) return;

    const element_type = singleTypeArgument(tree, reference.type_arguments) orelse return;
    if (!isSimpleType(tree, element_type)) return;

    const type_text = sourceText(tree, index);
    const element_text = sourceText(tree, unwrapParenthesized(tree, element_type));

    if (readonly) {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "Array type using '{s}' is forbidden for simple types. Use 'readonly {s}[]' instead.",
            .{ type_text, element_text },
        );
    } else {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(index),
            "Array type using '{s}' is forbidden for simple types. Use '{s}[]' instead.",
            .{ type_text, element_text },
        );
    }
}

pub fn checkArrayType(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    array_type: ast.TSArrayType,
    index: ast.NodeIndex,
) Allocator.Error!void {
    if (isSimpleType(tree, array_type.element_type)) return;

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "Array type using 'T[]' is forbidden for non-simple types. Use 'Array<T>' instead.",
        tree.span(index),
    );
}

fn singleTypeArgument(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.NodeIndex {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .ts_type_parameter_instantiation => |instantiation| {
            const params = tree.extra(instantiation.params);
            if (params.len != 1) return null;
            return params[0];
        },
        else => null,
    };
}

fn isSimpleType(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    if (index == .null) return false;

    return switch (tree.data(unwrapParenthesized(tree, index))) {
        .ts_array_type => true,
        .ts_any_keyword,
        .ts_bigint_keyword,
        .ts_boolean_keyword,
        .ts_intrinsic_keyword,
        .ts_never_keyword,
        .ts_null_keyword,
        .ts_number_keyword,
        .ts_object_keyword,
        .ts_string_keyword,
        .ts_symbol_keyword,
        .ts_this_type,
        .ts_undefined_keyword,
        .ts_unknown_keyword,
        .ts_void_keyword,
        => true,
        .ts_type_reference => |reference| reference.type_arguments == .null,
        else => false,
    };
}

fn unwrapParenthesized(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;
    while (current != .null) {
        switch (tree.data(current)) {
            .ts_parenthesized_type => |parenthesized| current = parenthesized.type_annotation,
            else => return current,
        }
    }
    return current;
}

fn typeName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn sourceText(tree: *const ast.Tree, index: ast.NodeIndex) []const u8 {
    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (start > end or end > tree.source.len) return "Array<T>";
    return tree.source[start..end];
}
