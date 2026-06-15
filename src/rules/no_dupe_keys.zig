const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-dupe-keys";

const SeenKey = struct {
    name: []const u8,
    owned: bool = false,
    init: bool = false,
    get: bool = false,
    set: bool = false,
};

const PropertyName = struct {
    value: []const u8,
    owned: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ObjectExpression,
) Allocator.Error!void {
    var seen: std.ArrayList(SeenKey) = .empty;
    defer {
        for (seen.items) |entry| {
            if (entry.owned) allocator.free(entry.name);
        }
        seen.deinit(allocator);
    }

    for (tree.extra(expression.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };

        const name = try propertyName(allocator, tree, property) orelse continue;
        if (try isDuplicate(allocator, &seen, name, property.kind)) {
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .warning,
                id,
                tree.span(property_index),
                "Duplicate key `{s}`.",
                .{name.value},
            );
        }
    }
}

fn isDuplicate(
    allocator: Allocator,
    seen: *std.ArrayList(SeenKey),
    name: PropertyName,
    kind: ast.PropertyKind,
) Allocator.Error!bool {
    for (seen.items) |*entry| {
        if (!std.mem.eql(u8, entry.name, name.value)) continue;
        if (name.owned) allocator.free(name.value);

        return switch (kind) {
            .init => true,
            .get => blk: {
                if (entry.init or entry.get) break :blk true;
                entry.get = true;
                break :blk false;
            },
            .set => blk: {
                if (entry.init or entry.set) break :blk true;
                entry.set = true;
                break :blk false;
            },
        };
    }

    try seen.append(allocator, .{
        .name = name.value,
        .owned = name.owned,
        .init = kind == .init,
        .get = kind == .get,
        .set = kind == .set,
    });
    return false;
}

fn propertyName(allocator: Allocator, tree: *const ast.Tree, property: ast.ObjectProperty) Allocator.Error!?PropertyName {
    if (property.computed or property.key == .null) return null;

    return switch (tree.data(property.key)) {
        .identifier_name => |identifier| .{ .value = tree.string(identifier.name) },
        .string_literal => |literal| .{ .value = tree.string(literal.value) },
        .numeric_literal => |literal| .{ .value = try numericPropertyName(allocator, tree, literal), .owned = true },
        else => null,
    };
}

fn numericPropertyName(allocator: Allocator, tree: *const ast.Tree, literal: ast.NumericLiteral) Allocator.Error![]const u8 {
    const value = literal.value(tree);
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}
