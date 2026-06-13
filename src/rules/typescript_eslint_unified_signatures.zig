const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/unified-signatures";

const Signature = struct {
    name: []const u8,
    node: ast.NodeIndex,
    params: ast.NodeIndex,
    return_type: ast.NodeIndex,
};

const Param = struct {
    node: ast.NodeIndex,
    type_text: []const u8,
    optional: bool,
};

pub fn checkRange(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    members: ast.IndexRange,
) Allocator.Error!void {
    var seen: std.ArrayList(Signature) = .empty;
    defer seen.deinit(allocator);

    for (tree.extra(members)) |member_index| {
        const current = signatureInfo(tree, member_index) orelse continue;
        for (seen.items) |previous| {
            if (!std.mem.eql(u8, previous.name, current.name)) continue;
            try compareSignatures(allocator, diagnostics, tree, previous, current);
        }
        try seen.append(allocator, current);
    }
}

fn compareSignatures(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    previous: Signature,
    current: Signature,
) Allocator.Error!void {
    if (!sameReturnType(tree, previous.return_type, current.return_type)) return;

    const previous_params = params(tree, previous.params) orelse return;
    const current_params = params(tree, current.params) orelse return;
    if (previous_params.rest != .null or current_params.rest != .null) return;

    const previous_items = tree.extra(previous_params.items);
    const current_items = tree.extra(current_params.items);

    if (previous_items.len == current_items.len) {
        try compareSameLength(allocator, diagnostics, tree, previous_items, current_items);
        return;
    }

    if (previous_items.len + 1 == current_items.len and paramsPrefixMatches(tree, previous_items, current_items[0..previous_items.len])) {
        try addOptionalDiagnostic(allocator, diagnostics, tree, current_items[previous_items.len]);
        return;
    }

    if (current_items.len + 1 == previous_items.len and paramsPrefixMatches(tree, current_items, previous_items[0..current_items.len])) {
        try addOptionalDiagnostic(allocator, diagnostics, tree, previous_items[current_items.len]);
    }
}

fn compareSameLength(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    previous_items: []const ast.NodeIndex,
    current_items: []const ast.NodeIndex,
) Allocator.Error!void {
    var mismatch_count: usize = 0;
    var mismatch_param: ast.NodeIndex = .null;
    var first_type: []const u8 = "";
    var second_type: []const u8 = "";

    for (previous_items, current_items) |previous_item, current_item| {
        const previous_param = paramInfo(tree, previous_item) orelse return;
        const current_param = paramInfo(tree, current_item) orelse return;
        if (previous_param.optional != current_param.optional) return;

        if (!std.mem.eql(u8, previous_param.type_text, current_param.type_text)) {
            mismatch_count += 1;
            mismatch_param = current_param.node;
            first_type = previous_param.type_text;
            second_type = current_param.type_text;
        }
    }

    if (mismatch_count == 1) {
        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(mismatch_param),
            "These overloads can be combined into one signature taking `{s} | {s}`.",
            .{ first_type, second_type },
        );
    }
}

fn paramsPrefixMatches(tree: *const ast.Tree, previous_items: []const ast.NodeIndex, current_items: []const ast.NodeIndex) bool {
    for (previous_items, current_items) |previous_item, current_item| {
        const previous_param = paramInfo(tree, previous_item) orelse return false;
        const current_param = paramInfo(tree, current_item) orelse return false;
        if (previous_param.optional != current_param.optional) return false;
        if (!std.mem.eql(u8, previous_param.type_text, current_param.type_text)) return false;
    }
    return true;
}

fn addOptionalDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    param_index: ast.NodeIndex,
) Allocator.Error!void {
    try core.addDiagnostic(
        allocator,
        diagnostics,
        .warning,
        id,
        "These overloads can be combined into one signature with an optional parameter.",
        tree.span(param_index),
    );
}

fn signatureInfo(tree: *const ast.Tree, index: ast.NodeIndex) ?Signature {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .export_named_declaration => |declaration| signatureInfo(tree, declaration.declaration),
        .export_default_declaration => |declaration| signatureInfo(tree, declaration.declaration),
        .function => |function| functionSignature(tree, function, index),
        .ts_method_signature => |signature| methodSignature(tree, signature, index),
        else => null,
    };
}

fn functionSignature(tree: *const ast.Tree, function: ast.Function, index: ast.NodeIndex) ?Signature {
    switch (function.type) {
        .function_declaration,
        .ts_declare_function,
        => {},
        else => return null,
    }
    if (function.body != .null) return null;

    const name = bindingIdentifierName(tree, function.id) orelse return null;
    return .{ .name = name, .node = index, .params = function.params, .return_type = function.return_type };
}

fn methodSignature(tree: *const ast.Tree, signature: ast.TSMethodSignature, index: ast.NodeIndex) ?Signature {
    if (signature.kind != .method) return null;
    const name = keyName(tree, signature.key, signature.computed) orelse return null;
    return .{ .name = name, .node = index, .params = signature.params, .return_type = signature.return_type };
}

fn params(tree: *const ast.Tree, index: ast.NodeIndex) ?ast.FormalParameters {
    return switch (tree.data(index)) {
        .formal_parameters => |parameters| parameters,
        else => null,
    };
}

fn paramInfo(tree: *const ast.Tree, index: ast.NodeIndex) ?Param {
    return switch (tree.data(index)) {
        .formal_parameter => |parameter| patternParamInfo(tree, parameter.pattern, index),
        else => null,
    };
}

fn patternParamInfo(tree: *const ast.Tree, pattern: ast.NodeIndex, param_index: ast.NodeIndex) ?Param {
    return switch (tree.data(pattern)) {
        .binding_identifier => |identifier| typedParam(tree, identifier.type_annotation, identifier.optional, param_index),
        .assignment_pattern => |assignment| typedParam(tree, assignment.type_annotation, true, param_index),
        else => null,
    };
}

fn typedParam(tree: *const ast.Tree, type_annotation: ast.NodeIndex, optional: bool, param_index: ast.NodeIndex) ?Param {
    const type_text = typeAnnotationText(tree, type_annotation) orelse return null;
    return .{ .node = param_index, .type_text = type_text, .optional = optional };
}

fn sameReturnType(tree: *const ast.Tree, left: ast.NodeIndex, right: ast.NodeIndex) bool {
    const left_text = typeAnnotationText(tree, left) orelse "";
    const right_text = typeAnnotationText(tree, right) orelse "";
    return std.mem.eql(u8, left_text, right_text);
}

fn typeAnnotationText(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;
    const type_index = switch (tree.data(index)) {
        .ts_type_annotation => |annotation| annotation.type_annotation,
        else => index,
    };
    return sourceText(tree, type_index);
}

fn sourceText(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (start >= end or end > tree.source.len) return null;
    return std.mem.trim(u8, tree.source[start..end], " \t\r\n");
}

fn bindingIdentifierName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn keyName(tree: *const ast.Tree, index: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (computed or index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .private_identifier => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
        else => null,
    };
}
