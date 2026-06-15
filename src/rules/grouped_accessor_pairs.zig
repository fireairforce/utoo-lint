const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "grouped-accessor-pairs";

const AccessorKind = enum {
    get,
    set,
};

pub const Style = enum {
    any_order,
    get_before_set,
    set_before_get,
};

const Accessor = struct {
    name: []const u8,
    static: bool = false,
    kind: AccessorKind,
    position: usize,
    index: ast.NodeIndex,
};

pub fn checkObjectExpression(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ObjectExpression,
) Allocator.Error!void {
    return checkObjectExpressionWithStyle(allocator, diagnostics, tree, expression, .any_order);
}

pub fn checkObjectExpressionWithStyle(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ObjectExpression,
    style: Style,
) Allocator.Error!void {
    var accessors: std.ArrayList(Accessor) = .empty;
    defer accessors.deinit(allocator);

    for (tree.extra(expression.properties), 0..) |property_index, position| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };
        const kind: AccessorKind = switch (property.kind) {
            .get => .get,
            .set => .set,
            else => continue,
        };
        const name = propertyName(tree, property.key, property.computed) orelse continue;

        try accessors.append(allocator, .{
            .name = name,
            .kind = kind,
            .position = position,
            .index = property_index,
        });
    }

    try checkAccessors(allocator, diagnostics, tree, accessors.items, style);
}

pub fn checkClassBody(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.ClassBody,
) Allocator.Error!void {
    return checkClassBodyWithStyle(allocator, diagnostics, tree, body, .any_order);
}

pub fn checkClassBodyWithStyle(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.ClassBody,
    style: Style,
) Allocator.Error!void {
    var accessors: std.ArrayList(Accessor) = .empty;
    defer accessors.deinit(allocator);

    for (tree.extra(body.body), 0..) |member_index, position| {
        const method = switch (tree.data(member_index)) {
            .method_definition => |method| method,
            else => continue,
        };
        const kind: AccessorKind = switch (method.kind) {
            .get => .get,
            .set => .set,
            else => continue,
        };
        const name = propertyName(tree, method.key, method.computed) orelse continue;

        try accessors.append(allocator, .{
            .name = name,
            .static = method.static,
            .kind = kind,
            .position = position,
            .index = member_index,
        });
    }

    try checkAccessors(allocator, diagnostics, tree, accessors.items, style);
}

fn checkAccessors(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    accessors: []const Accessor,
    style: Style,
) Allocator.Error!void {
    for (accessors, 0..) |accessor, index| {
        const previous = previousCounterpart(accessors[0..index], accessor) orelse continue;
        if (previous.position + 1 == accessor.position and orderMatches(style, previous.kind, accessor.kind)) continue;

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .warning,
            id,
            tree.span(accessor.index),
            "Getter and setter for '{s}' should be grouped together.",
            .{accessor.name},
        );
    }
}

fn orderMatches(style: Style, previous: AccessorKind, current: AccessorKind) bool {
    return switch (style) {
        .any_order => true,
        .get_before_set => previous == .get and current == .set,
        .set_before_get => previous == .set and current == .get,
    };
}

fn previousCounterpart(previous_accessors: []const Accessor, accessor: Accessor) ?Accessor {
    var index = previous_accessors.len;
    while (index > 0) {
        index -= 1;
        const previous = previous_accessors[index];
        if (previous.static != accessor.static) continue;
        if (previous.kind == accessor.kind) continue;
        if (!std.mem.eql(u8, previous.name, accessor.name)) continue;
        return previous;
    }
    return null;
}

fn propertyName(tree: *const ast.Tree, key: ast.NodeIndex, computed: bool) ?[]const u8 {
    if (key == .null) return null;

    return switch (tree.data(key)) {
        .identifier_name => |identifier| if (computed) null else tree.string(identifier.name),
        .private_identifier => |identifier| if (computed) null else tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
        .identifier_reference => if (computed) sourceSlice(tree, key) else null,
        .template_literal => |literal| templateStringValue(tree, literal) orelse if (computed) sourceSlice(tree, key) else null,
        else => null,
    };
}

fn templateStringValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;

    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return "";

    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
}

fn sourceSlice(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);
    if (start >= end or end > tree.source.len) return null;

    return tree.source[start..end];
}
