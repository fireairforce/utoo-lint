const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/triple-slash-reference";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    for (tree.comments) |comment| {
        if (comment.type != .line) continue;

        const path = referencePath(tree.string(comment.value)) orelse continue;

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .@"error",
            id,
            .{ .start = comment.start, .end = comment.end },
            "Do not use a triple slash reference for {s}, use `import` style instead.",
            .{path},
        );
    }
}

fn referencePath(value: []const u8) ?[]const u8 {
    if (value.len == 0 or value[0] != '/') return null;

    const body = trimLeftWhitespace(value[1..]);
    if (!std.mem.startsWith(u8, body, "<reference")) return null;

    const path_index = std.mem.indexOf(u8, body, "path=") orelse return null;
    var rest = body[path_index + "path=".len ..];
    rest = trimLeftWhitespace(rest);
    if (rest.len < 2) return null;

    const quote = rest[0];
    if (quote != '"' and quote != '\'') return null;
    const end = std.mem.indexOfScalar(u8, rest[1..], quote) orelse return null;
    return rest[1..][0..end];
}

fn trimLeftWhitespace(value: []const u8) []const u8 {
    var index: usize = 0;
    while (index < value.len and (value[index] == ' ' or value[index] == '\t')) : (index += 1) {}
    return value[index..];
}
