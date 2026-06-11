const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-dupe-keys";

const SeenKey = struct {
    name: []const u8,
    init: bool = false,
    get: bool = false,
    set: bool = false,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    expression: ast.ObjectExpression,
) Allocator.Error!void {
    var seen: std.ArrayList(SeenKey) = .empty;
    defer seen.deinit(allocator);

    for (tree.extra(expression.properties)) |property_index| {
        const property = switch (tree.data(property_index)) {
            .object_property => |property| property,
            else => continue,
        };

        const name = propertyName(tree, property) orelse continue;
        if (try isDuplicate(allocator, &seen, name, property.kind)) {
            try core.addDiagnosticFmt(
                allocator,
                diagnostics,
                .warning,
                id,
                tree.span(property_index),
                "Duplicate key `{s}`.",
                .{name},
            );
        }
    }
}

fn isDuplicate(
    allocator: Allocator,
    seen: *std.ArrayList(SeenKey),
    name: []const u8,
    kind: ast.PropertyKind,
) Allocator.Error!bool {
    for (seen.items) |*entry| {
        if (!std.mem.eql(u8, entry.name, name)) continue;

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
        .name = name,
        .init = kind == .init,
        .get = kind == .get,
        .set = kind == .set,
    });
    return false;
}

fn propertyName(tree: *const ast.Tree, property: ast.ObjectProperty) ?[]const u8 {
    if (property.computed or property.key == .null) return null;

    return switch (tree.data(property.key)) {
        .identifier_name => |identifier| tree.string(identifier.name),
        .string_literal => |literal| tree.string(literal.value),
        .numeric_literal => |literal| tree.string(literal.raw),
        else => null,
    };
}
