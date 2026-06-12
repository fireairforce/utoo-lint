const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/ban-types";

const BannedType = struct {
    name: []const u8,
    message: []const u8,
};

pub fn checkTypeReference(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    reference: ast.TSTypeReference,
) Allocator.Error!void {
    const name = typeName(tree, reference.type_name) orelse return;
    const banned = bannedType(name) orelse return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(reference.type_name),
        "Don't use `{s}` as a type. {s}",
        .{ banned.name, banned.message },
    );
}

fn bannedType(name: []const u8) ?BannedType {
    if (std.mem.eql(u8, name, "String")) return .{
        .name = "String",
        .message = "Use string instead",
    };
    if (std.mem.eql(u8, name, "Boolean")) return .{
        .name = "Boolean",
        .message = "Use boolean instead",
    };
    if (std.mem.eql(u8, name, "Number")) return .{
        .name = "Number",
        .message = "Use number instead",
    };
    if (std.mem.eql(u8, name, "Symbol")) return .{
        .name = "Symbol",
        .message = "Use symbol instead",
    };
    if (std.mem.eql(u8, name, "BigInt")) return .{
        .name = "BigInt",
        .message = "Use bigint instead",
    };
    if (std.mem.eql(u8, name, "Function")) return .{
        .name = "Function",
        .message = "The `Function` type accepts any function-like value.\n" ++
            "It provides no type safety when calling the function, which can be a common source of bugs.\n" ++
            "It also accepts things like class declarations, which will throw at runtime as they will not be called with `new`.\n" ++
            "If you are expecting the function to accept certain arguments, you should explicitly define the function shape.",
    };
    if (std.mem.eql(u8, name, "Object")) return .{
        .name = "Object",
        .message = "The `Object` type actually means \"any non-nullish value\", so it is marginally better than `unknown`.\n" ++
            "- If you want a type meaning \"any object\", you probably want `object` instead.\n" ++
            "- If you want a type meaning \"any value\", you probably want `unknown` instead.\n" ++
            "- If you really want a type meaning \"any non-nullish value\", you probably want `NonNullable<unknown>` instead.",
    };

    return null;
}

fn typeName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    return switch (tree.data(index)) {
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}
