const parser = @import("parser");
const core = @import("../core.zig");
const std = @import("std");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-invalid-void-type";

pub const Options = struct {
    allow_as_this_parameter: bool = false,
    allow_in_generic_type_arguments: bool = true,
    allowed_generic_type_names: core.TypescriptEslintNoInvalidVoidTypeAllowedGenericTypeNames = .{},
};

const Ancestor = struct {
    index: ast.NodeIndex,
    depth: usize,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    return checkWithOptions(allocator, diagnostics, tree, index, ctx, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    const parent = nearestNonParenthesizedAncestor(tree, ctx, 1) orelse return;

    switch (tree.data(parent.index)) {
        .ts_union_type => {
            try core.addDiagnostic(
                allocator,
                diagnostics,
                .@"error",
                id,
                "void is not valid as a constituent in a union type",
                tree.span(index),
            );
            return;
        },
        .ts_type_parameter_instantiation => {
            if (options.allow_in_generic_type_arguments) return;
            if (allowedGenericTypeArgument(tree, parent.index, ctx.path.ancestor(parent.depth + 1), &options.allowed_generic_type_names)) return;
        },
        .ts_type_annotation => {
            if (isReturnTypeAnnotation(tree, parent.index, ctx.path.ancestor(parent.depth + 1))) return;
            if (options.allow_as_this_parameter and isThisParameterAnnotation(tree, parent.index, ctx.path.ancestor(parent.depth + 1))) return;
        },
        else => {},
    }

    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "void is only valid as a return type or generic type argument.",
        tree.span(index),
    );
}

fn nearestNonParenthesizedAncestor(tree: *const ast.Tree, ctx: *traverser.basic.Ctx, start_depth: usize) ?Ancestor {
    var depth = start_depth;
    while (ctx.path.ancestor(depth)) |ancestor| : (depth += 1) {
        switch (tree.data(ancestor)) {
            .ts_parenthesized_type => {},
            else => return .{ .index = ancestor, .depth = depth },
        }
    }
    return null;
}

fn isReturnTypeAnnotation(tree: *const ast.Tree, annotation_index: ast.NodeIndex, owner_index: ?ast.NodeIndex) bool {
    const owner = owner_index orelse return false;

    return switch (tree.data(owner)) {
        .function => |function| function.return_type == annotation_index,
        .arrow_function_expression => |arrow| arrow.return_type == annotation_index,
        .ts_function_type => |function_type| function_type.return_type == annotation_index,
        .ts_constructor_type => |constructor_type| constructor_type.return_type == annotation_index,
        .ts_method_signature => |signature| signature.return_type == annotation_index,
        .ts_call_signature_declaration => |signature| signature.return_type == annotation_index,
        .ts_construct_signature_declaration => |signature| signature.return_type == annotation_index,
        else => false,
    };
}

fn isThisParameterAnnotation(tree: *const ast.Tree, annotation_index: ast.NodeIndex, owner_index: ?ast.NodeIndex) bool {
    const owner = owner_index orelse return false;

    return switch (tree.data(owner)) {
        .ts_this_parameter => |parameter| parameter.type_annotation == annotation_index,
        else => false,
    };
}

fn allowedGenericTypeArgument(
    tree: *const ast.Tree,
    type_arguments_index: ast.NodeIndex,
    owner_index: ?ast.NodeIndex,
    allowed_names: *const core.TypescriptEslintNoInvalidVoidTypeAllowedGenericTypeNames,
) bool {
    const owner = owner_index orelse return false;

    return switch (tree.data(owner)) {
        .ts_type_reference => |reference| reference.type_arguments == type_arguments_index and allowedGenericTypeName(tree, reference.type_name, allowed_names),
        else => false,
    };
}

fn allowedGenericTypeName(
    tree: *const ast.Tree,
    type_name_index: ast.NodeIndex,
    allowed_names: *const core.TypescriptEslintNoInvalidVoidTypeAllowedGenericTypeNames,
) bool {
    const name = switch (tree.data(type_name_index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        .ts_qualified_name => sourceText(tree, type_name_index),
        else => return false,
    };

    return allowed_names.contains(std.mem.trim(u8, name, " \t\r\n"));
}

fn sourceText(tree: *const ast.Tree, index: ast.NodeIndex) []const u8 {
    const span = tree.span(index);
    return tree.source[span.start..span.end];
}
