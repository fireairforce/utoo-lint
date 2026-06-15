const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/ant/prefer-managed-resource";

const allow_keywords = [_][]const u8{
    "resource-hub",
    "mars",
    "marketing",
    "/managed_asset/managed/img",
    "fecodex_image",
};

pub fn checkStringLiteral(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.StringLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const value = tree.string(literal.value);
    if (!isResourceUrl(value)) return;
    if (hasAllowedKeyword(value)) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "静态资源({s})推荐使用资源管理平台进行上传使用(https://assets.example.com/space).",
        .{value},
    );
}

fn isResourceUrl(value: []const u8) bool {
    if (!std.mem.startsWith(u8, value, "http://") and !std.mem.startsWith(u8, value, "https://")) return false;
    return std.mem.indexOf(u8, value, "/managed/img") != null or
        std.mem.indexOf(u8, value, ".png") != null or
        std.mem.indexOf(u8, value, ".jpeg") != null or
        std.mem.indexOf(u8, value, ".webp") != null or
        std.mem.indexOf(u8, value, ".avif") != null;
}

fn hasAllowedKeyword(value: []const u8) bool {
    for (allow_keywords) |keyword| {
        if (std.mem.indexOf(u8, value, keyword) != null) return true;
    }
    return false;
}
