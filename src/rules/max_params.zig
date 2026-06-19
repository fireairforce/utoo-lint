const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "max-params";

pub const Options = struct {
    max: usize = 3,
    count_this: core.MaxParamsCountThis = .except_void,
};

pub fn checkFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    function: ast.Function,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    try checkParams(allocator, diagnostics, tree, function.params, index, "Function", options);
}

pub fn checkArrowFunction(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ArrowFunctionExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    try checkParams(allocator, diagnostics, tree, expression.params, index, "Arrow function", options);
}

fn checkParams(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    params_index: ast.NodeIndex,
    index: ast.NodeIndex,
    kind: []const u8,
    options: Options,
) Allocator.Error!void {
    const params = formalParameters(tree, params_index) orelse return;
    const count = parameterCount(tree, params, options);
    if (count <= options.max) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "{s} has too many parameters ({d}). Maximum allowed is {d}.",
        .{ kind, count, options.max },
    );
}

fn parameterCount(tree: *const ast.Tree, params: ast.FormalParameters, options: Options) usize {
    var count: usize = 0;
    for (tree.extra(params.items)) |item| {
        switch (tree.data(item)) {
            .formal_parameter => |parameter| {
                if (isSkippedThisParameter(tree, parameter.pattern, options.count_this)) continue;
                count += 1;
            },
            .ts_parameter_property => count += 1,
            else => {},
        }
    }
    if (params.rest != .null) count += 1;
    return count;
}

fn isSkippedThisParameter(tree: *const ast.Tree, pattern: ast.NodeIndex, count_this: core.MaxParamsCountThis) bool {
    const this_parameter = switch (tree.data(pattern)) {
        .ts_this_parameter => |parameter| parameter,
        else => return false,
    };

    return switch (count_this) {
        .always => false,
        .never => true,
        .except_void => isVoidThisParameter(tree, this_parameter),
    };
}

fn isVoidThisParameter(tree: *const ast.Tree, parameter: ast.TSThisParameter) bool {
    if (parameter.type_annotation == .null) return false;
    const annotation = switch (tree.data(parameter.type_annotation)) {
        .ts_type_annotation => |annotation| annotation,
        else => return false,
    };
    return switch (tree.data(annotation.type_annotation)) {
        .ts_void_keyword => true,
        else => false,
    };
}

fn formalParameters(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.FormalParameters {
    if (index == .null) return null;
    return switch (tree.data(index)) {
        .formal_parameters => |params| params,
        else => null,
    };
}
