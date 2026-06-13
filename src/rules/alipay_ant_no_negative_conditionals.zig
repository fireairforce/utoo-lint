const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/ant/no-negative-conditionals";

pub fn checkNode(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    data: ast.NodeData,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const name = identifierName(tree, data) orelse return;
    if (!isNegativeConditionalName(name)) return;

    const instead = try replacementName(allocator, name);
    defer allocator.free(instead);

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .@"error",
        id,
        tree.span(index),
        "use `{s}` instead `{s}`.",
        .{ instead, name },
    );
}

fn identifierName(tree: *const ast.Tree, data: ast.NodeData) ?[]const u8 {
    return switch (data) {
        .binding_identifier => |identifier| tree.string(identifier.name),
        .identifier_reference => |identifier| tree.string(identifier.name),
        .identifier_name => |identifier| tree.string(identifier.name),
        else => null,
    };
}

fn isNegativeConditionalName(name: []const u8) bool {
    if (!std.mem.startsWith(u8, name, "is") and !std.mem.startsWith(u8, name, "IS")) return false;

    var index: usize = 0;
    while (index < name.len) : (index += 1) {
        if (std.mem.startsWith(u8, name[index..], "Not")) {
            const after = index + "Not".len;
            return after >= name.len or !std.ascii.isLower(name[after]);
        }
        if (std.mem.startsWith(u8, name[index..], "NOT")) {
            const after = index + "NOT".len;
            return after >= name.len or !std.ascii.isUpper(name[after]);
        }
    }
    return false;
}

fn replacementName(allocator: Allocator, name: []const u8) Allocator.Error![]u8 {
    const index = caseInsensitiveIndexOf(name, "not") orelse return allocator.dupe(u8, name);
    const start = if (index > 0 and name[index - 1] == '_') index - 1 else index;

    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try result.appendSlice(allocator, name[0..start]);
    try result.appendSlice(allocator, name[index + "not".len ..]);
    return result.toOwnedSlice(allocator);
}

fn caseInsensitiveIndexOf(value: []const u8, needle: []const u8) ?usize {
    if (needle.len == 0) return 0;
    if (needle.len > value.len) return null;

    var index: usize = 0;
    while (index + needle.len <= value.len) : (index += 1) {
        if (std.ascii.eqlIgnoreCase(value[index .. index + needle.len], needle)) return index;
    }
    return null;
}
