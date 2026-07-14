const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-useless-rename";

pub const Options = struct {
    ignore_destructuring: bool = false,
    ignore_import: bool = false,
    ignore_export: bool = false,
};

pub fn checkImportSpecifier(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    specifier: ast.ImportSpecifier,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkImportSpecifierWithOptions(allocator, diagnostics, tree, specifier, index, .{});
}

pub fn checkImportSpecifierWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    specifier: ast.ImportSpecifier,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (options.ignore_import) return;
    if (!hasAsBetween(tree, specifier.imported, specifier.local)) return;

    const imported = propertyName(tree, specifier.imported) orelse return;
    const local = bindingName(tree, specifier.local) orelse return;
    if (!std.mem.eql(u8, imported, local)) return;

    try addDiagnostic(allocator, diagnostics, tree, index, specifier.local);
}

pub fn checkExportSpecifier(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    specifier: ast.ExportSpecifier,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkExportSpecifierWithOptions(allocator, diagnostics, tree, specifier, index, .{});
}

pub fn checkExportSpecifierWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    specifier: ast.ExportSpecifier,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (options.ignore_export) return;
    if (!hasAsBetween(tree, specifier.local, specifier.exported)) return;

    const local = referenceOrPropertyName(tree, specifier.local) orelse return;
    const exported = propertyName(tree, specifier.exported) orelse return;
    if (!std.mem.eql(u8, local, exported)) return;

    try addDiagnostic(allocator, diagnostics, tree, index, specifier.local);
}

pub fn checkObjectPattern(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    pattern: ast.ObjectPattern,
) Allocator.Error!void {
    try checkObjectPatternWithOptions(allocator, diagnostics, tree, pattern, .{});
}

pub fn checkObjectPatternWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    pattern: ast.ObjectPattern,
    options: Options,
) Allocator.Error!void {
    if (options.ignore_destructuring) return;
    for (tree.extra(pattern.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .binding_property => |property| property,
            else => continue,
        };
        if (property.shorthand or property.computed) continue;

        const key = propertyName(tree, property.key) orelse continue;
        const value = bindingOrAssignmentName(tree, property.value) orelse continue;
        if (!std.mem.eql(u8, key, value)) continue;

        try addDiagnostic(allocator, diagnostics, tree, property_index, property.value);
    }
}

pub fn checkAssignmentExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
) Allocator.Error!void {
    try checkAssignmentExpressionWithOptions(allocator, diagnostics, tree, expression, .{});
}

pub fn checkAssignmentExpressionWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.AssignmentExpression,
    options: Options,
) Allocator.Error!void {
    if (options.ignore_destructuring) return;
    if (expression.operator != .assign) return;

    switch (tree.data(unwrapTransparent(tree, expression.left))) {
        .object_pattern => |pattern| try checkAssignmentObjectPattern(allocator, diagnostics, tree, pattern),
        else => {},
    }
}

fn checkAssignmentObjectPattern(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    pattern: ast.ObjectPattern,
) Allocator.Error!void {
    for (tree.extra(pattern.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .binding_property => |property| property,
            else => continue,
        };
        if (property.shorthand or property.computed) continue;

        switch (tree.data(unwrapTransparent(tree, property.value))) {
            .object_pattern => |nested| {
                try checkAssignmentObjectPattern(allocator, diagnostics, tree, nested);
                continue;
            },
            else => {},
        }

        const key = propertyName(tree, property.key) orelse continue;
        const value = referenceOrAssignmentName(tree, property.value) orelse continue;
        if (!std.mem.eql(u8, key, value)) continue;

        try addDiagnostic(allocator, diagnostics, tree, property_index, property.value);
    }
}

fn referenceOrAssignmentName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(unwrapTransparent(tree, index))) {
        .assignment_pattern => |pattern| referenceOrPropertyName(tree, pattern.left),
        else => referenceOrPropertyName(tree, unwrapTransparent(tree, index)),
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

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
    replacement_index: ast.NodeIndex,
) Allocator.Error!void {
    const span = tree.span(index);
    const replacement_span = tree.span(replacement_index);
    if (wouldDiscardComment(tree, span, replacement_span)) {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Useless rename to the same name.",
            span,
        );
        return;
    }

    try core.addDiagnosticWithFix(
        allocator,
        diagnostics,
        .warning,
        id,
        "Useless rename to the same name.",
        span,
        .{
            .span = span,
            .replacement = tree.source[@intCast(replacement_span.start)..@intCast(replacement_span.end)],
        },
    );
}

fn wouldDiscardComment(tree: *const ast.Tree, span: ast.Span, replacement_span: ast.Span) bool {
    for (tree.comments) |comment| {
        const inside_span = comment.span.start >= span.start and comment.span.end <= span.end;
        if (!inside_span) continue;

        const inside_replacement = comment.span.start >= replacement_span.start and
            comment.span.end <= replacement_span.end;
        if (!inside_replacement) return true;
    }
    return false;
}

fn bindingOrAssignmentName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .assignment_pattern => |pattern| bindingName(tree, pattern.left),
        else => bindingName(tree, index),
    };
}

fn bindingName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn referenceOrPropertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        else => propertyName(tree, index),
    };
}

fn propertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
        else => null,
    };
}

fn hasAsBetween(tree: *const ast.Tree, left: ast.NodeIndex, right: ast.NodeIndex) bool {
    if (left == .null or right == .null) return false;

    const left_span = tree.span(left);
    const right_span = tree.span(right);
    const left_end: usize = @intCast(left_span.end);
    const right_start: usize = @intCast(right_span.start);
    if (left_end > right_start or right_start > tree.source.len) return false;

    var iter = std.mem.tokenizeAny(u8, tree.source[left_end..right_start], " \t\r\n");
    while (iter.next()) |token| {
        if (std.mem.eql(u8, token, "as")) return true;
    }
    return false;
}
