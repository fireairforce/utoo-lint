const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "promise/param-names";

pub const Options = struct {
    resolve_pattern: core.PromiseParamNamePattern = .{},
    reject_pattern: core.PromiseParamNamePattern = .{ .default = .reject },
};

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.NewExpression,
    options: Options,
) Allocator.Error!void {
    if (!identifierReferenceNamed(tree, expression.callee, "Promise")) return;
    const arguments = tree.extra(expression.arguments);
    if (arguments.len != 1) return;

    const params_index = switch (tree.data(unwrapTransparent(tree, arguments[0]))) {
        .function => |function| if (function.type == .function_expression) function.params else return,
        .arrow_function_expression => |arrow| arrow.params,
        else => return,
    };
    const params = switch (tree.data(params_index)) {
        .formal_parameters => |params| tree.extra(params.items),
        else => return,
    };
    if (params.len > 0) {
        try checkParameter(allocator, diagnostics, tree, params[0], options.resolve_pattern);
    }
    if (params.len > 1) {
        try checkParameter(allocator, diagnostics, tree, params[1], options.reject_pattern);
    }
}

fn checkParameter(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    parameter_index: ast.NodeIndex,
    pattern: core.PromiseParamNamePattern,
) Allocator.Error!void {
    const binding = switch (tree.data(parameter_index)) {
        .formal_parameter => |parameter| parameter.pattern,
        else => return,
    };
    const name = bindingIdentifierName(tree, binding) orelse return;
    if (pattern.matches(name)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(parameter_index),
        "Promise constructor parameters must be named to match \"{s}\"",
        .{pattern.pattern()},
    );
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn identifierReferenceNamed(tree: *const ast.Tree, index: ast.NodeIndex, name: []const u8) bool {
    return switch (tree.data(unwrapTransparent(tree, index))) {
        .identifier_reference => |identifier| std.mem.eql(u8, tree.string(identifier.name), name),
        else => false,
    };
}

fn unwrapTransparent(tree: *const ast.Tree, index: ast.NodeIndex) ast.NodeIndex {
    var current = index;
    while (current != .null) {
        switch (tree.data(current)) {
            .chain_expression => |chain| current = chain.expression,
            .parenthesized_expression => |parenthesized| current = parenthesized.expression,
            else => return current,
        }
    }
    return current;
}
