const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");
const no_empty_function = @import("no_empty_function.zig");

const ast = parser.ast;
const traverser = parser.traverser;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/no-empty-function";

pub const Options = struct {
    allow: core.NoEmptyFunctionAllow = .{},
    kind: no_empty_function.Kind = .functions,
};

pub fn checkFunctionBody(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.FunctionBody,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
) Allocator.Error!void {
    return checkFunctionBodyWithOptions(allocator, diagnostics, tree, body, index, ctx, .{});
}

pub fn checkFunctionBodyWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.FunctionBody,
    index: ast.NodeIndex,
    ctx: *traverser.basic.Ctx,
    options: Options,
) Allocator.Error!void {
    if (body.body.len != 0) return;
    if (no_empty_function.allowsKind(options.allow, options.kind)) return;
    if (allowsTypescriptConstructor(options.allow, tree, ctx)) return;
    if (no_empty_function.hasCommentInsideBraces(tree, index)) return;
    if (hasParameterPropertyConstructor(tree, ctx)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "Unexpected empty {s}.",
        .{functionDescription(tree, ctx)},
    );
}

fn allowsTypescriptConstructor(allow: core.NoEmptyFunctionAllow, tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    const method = parentMethod(tree, ctx) orelse return false;
    if (method.kind != .constructor) return false;
    return switch (method.accessibility) {
        .private => allow.privateConstructors,
        .protected => allow.protectedConstructors,
        else => false,
    };
}

fn hasParameterPropertyConstructor(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) bool {
    const function = parentFunction(tree, ctx) orelse return false;
    const method = parentMethod(tree, ctx) orelse return false;
    if (method.kind != .constructor) return false;

    const params = switch (tree.data(function.params)) {
        .formal_parameters => |params| params,
        else => return false,
    };

    for (tree.extra(params.items)) |item_index| {
        if (tree.data(item_index) == .ts_parameter_property) return true;
    }
    return false;
}

fn functionDescription(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) []const u8 {
    if (parentMethod(tree, ctx)) |method| {
        return switch (method.kind) {
            .constructor => "constructor",
            .method => methodDescription(tree, method, "method"),
            .get => methodDescription(tree, method, "getter"),
            .set => methodDescription(tree, method, "setter"),
        };
    }

    const parent_index = ctx.path.parent() orelse return "function";
    const function_index = ctx.path.ancestor(1) orelse parent_index;
    _ = function_index;

    return switch (tree.data(parent_index)) {
        .function => |function| switch (function.type) {
            .function_declaration => namedFunctionDescription(tree, function.id),
            else => "function",
        },
        .arrow_function_expression => "arrow function",
        else => "function",
    };
}

fn methodDescription(tree: *const ast.Tree, method: ast.MethodDefinition, kind: []const u8) []const u8 {
    const name = keyName(tree, method.key, method.computed) orelse return kind;
    if (std.mem.eql(u8, kind, "method")) {
        if (std.mem.eql(u8, name, "")) return kind;
        return "method";
    }
    return kind;
}

fn namedFunctionDescription(tree: *const ast.Tree, id_index: ast.NodeIndex) []const u8 {
    const name = bindingIdentifierName(tree, id_index) orelse return "function";
    if (name.len == 0) return "function";
    return "function";
}

fn parentFunction(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) ?ast.Function {
    const parent_index = ctx.path.parent() orelse return null;
    return switch (tree.data(parent_index)) {
        .function => |function| function,
        else => null,
    };
}

fn parentMethod(tree: *const ast.Tree, ctx: *traverser.basic.Ctx) ?ast.MethodDefinition {
    const grandparent_index = ctx.path.ancestor(2) orelse return null;
    return switch (tree.data(grandparent_index)) {
        .method_definition => |method| method,
        else => null,
    };
}

fn keyName(tree: *const ast.Tree, key: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (computed or key == .null) return null;
    return switch (tree.data(key)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
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
