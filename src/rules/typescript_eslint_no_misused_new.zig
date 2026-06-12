const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-misused-new";

pub fn checkInterfaceDeclaration(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    declaration: ast.TSInterfaceDeclaration,
) Allocator.Error!void {
    const name = bindingIdentifierName(tree, declaration.id) orelse return;
    const body = switch (tree.data(declaration.body)) {
        .ts_interface_body => |body| body,
        else => return,
    };

    for (tree.extra(body.body)) |member_index| {
        switch (tree.data(member_index)) {
            .ts_construct_signature_declaration => |signature| {
                if (isMatchingTypeName(tree, signature.return_type, name)) {
                    try reportInterface(allocator, diagnostics, tree, member_index);
                }
            },
            .ts_method_signature => |signature| {
                if (isConstructorMethodName(tree, signature.key, signature.computed)) {
                    try reportInterface(allocator, diagnostics, tree, member_index);
                }
            },
            else => {},
        }
    }
}

pub fn checkClass(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    class: ast.Class,
) Allocator.Error!void {
    const name = bindingIdentifierName(tree, class.id) orelse return;
    const body = switch (tree.data(class.body)) {
        .class_body => |body| body,
        else => return,
    };

    for (tree.extra(body.body)) |member_index| {
        const method = switch (tree.data(member_index)) {
            .method_definition => |method| method,
            else => continue,
        };
        if (!isNewMethodName(tree, method.key, method.computed)) continue;

        const function = switch (tree.data(method.value)) {
            .function => |function| function,
            else => continue,
        };
        if (function.type != .ts_empty_body_function_expression) continue;
        if (!isMatchingTypeName(tree, function.return_type, name)) continue;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .@"error",
            id,
            "Class cannot have method named `new`.",
            tree.span(member_index),
        );
    }
}

pub fn checkTypeLiteral(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    type_literal: ast.TSTypeLiteral,
) Allocator.Error!void {
    for (tree.extra(type_literal.members)) |member_index| {
        const signature = switch (tree.data(member_index)) {
            .ts_method_signature => |signature| signature,
            else => continue,
        };
        if (!isConstructorMethodName(tree, signature.key, signature.computed)) continue;

        try reportInterface(allocator, diagnostics, tree, member_index);
    }
}

fn reportInterface(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .@"error",
        id,
        "Interfaces cannot be constructed, only classes.",
        tree.span(index),
    );
}

fn isConstructorMethodName(tree: *const ast.Tree, key: ast.NodeIndex, computed: bool) bool {
    return keyNameEquals(tree, key, computed, "constructor");
}

fn isNewMethodName(tree: *const ast.Tree, key: ast.NodeIndex, computed: bool) bool {
    return keyNameEquals(tree, key, computed, "new");
}

fn keyNameEquals(tree: *const ast.Tree, key: ast.NodeIndex, computed: bool, expected: []const u8) bool {
    if (computed or key == .null) return false;

    const actual = switch (tree.data(key)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        else => return false,
    };
    return std.mem.eql(u8, actual, expected);
}

fn isMatchingTypeName(tree: *const ast.Tree, return_type: ast.NodeIndex, expected: []const u8) bool {
    const actual = typeReferenceName(tree, return_type) orelse return false;
    return std.mem.eql(u8, actual, expected);
}

fn typeReferenceName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .ts_type_annotation => |annotation| typeReferenceName(tree, annotation.type_annotation),
        .ts_type_reference => |reference| typeReferenceName(tree, reference.type_name),
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}
