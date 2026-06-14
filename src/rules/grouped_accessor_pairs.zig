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

    try checkAccessors(allocator, diagnostics, tree, accessors.items);
}

pub fn checkClassBody(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    body: ast.ClassBody,
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

    try checkAccessors(allocator, diagnostics, tree, accessors.items);
}

fn checkAccessors(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    accessors: []const Accessor,
) Allocator.Error!void {
    for (accessors, 0..) |accessor, index| {
        const previous = previousCounterpart(accessors[0..index], accessor) orelse continue;
        if (previous.position + 1 == accessor.position) continue;

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
        else => null,
    };
}
