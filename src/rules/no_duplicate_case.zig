const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-duplicate-case";

const SeenCase = struct {
    tag: std.meta.Tag(ast.NodeData),
    source: []const u8,
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    statement: ast.SwitchStatement,
) Allocator.Error!void {
    var seen: std.ArrayList(SeenCase) = .empty;
    defer seen.deinit(allocator);

    for (tree.extra(statement.cases)) |case_index| {
        const switch_case = switch (tree.data(case_index)) {
            .switch_case => |switch_case| switch_case,
            else => continue,
        };

        if (switch_case.@"test" == .null) continue;

        const tag = std.meta.activeTag(tree.data(switch_case.@"test"));
        const source = nodeSource(tree, switch_case.@"test") orelse continue;

        if (isDuplicate(seen.items, tag, source)) {
            try core.addDiagnostic(
                allocator,
                diagnostics,
                .warning,
                id,
                "Duplicate case label.",
                tree.span(case_index),
            );
        } else {
            try seen.append(allocator, .{
                .tag = tag,
                .source = source,
            });
        }
    }
}

fn isDuplicate(
    seen: []const SeenCase,
    tag: std.meta.Tag(ast.NodeData),
    source: []const u8,
) bool {
    for (seen) |entry| {
        if (entry.tag == tag and sourceEqual(entry.source, source)) return true;
    }
    return false;
}

fn nodeSource(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);

    if (start >= end or end > tree.source.len) return null;
    return std.mem.trim(u8, tree.source[start..end], " \t\r\n");
}

fn sourceEqual(left: []const u8, right: []const u8) bool {
    return std.mem.eql(u8, left, right);
}
