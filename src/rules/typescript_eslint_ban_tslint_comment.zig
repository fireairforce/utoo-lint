const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@typescript-eslint/ban-tslint-comment";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    for (tree.comments) |comment| {
        const value = tree.string(comment.value);
        if (!isTslintDirective(value)) continue;

        try core.addDiagnostic(
            allocator,
            diagnostics,
            .@"error",
            id,
            "tslint comment detected.",
            .{ .start = comment.span.start, .end = comment.span.end },
        );
    }
}

fn isTslintDirective(value: []const u8) bool {
    var text = trimLeftWhitespace(value);
    if (!std.mem.startsWith(u8, text, "tslint:")) return false;
    text = text["tslint:".len..];

    if (std.mem.startsWith(u8, text, "enable")) {
        return hasExpectedSuffix(text["enable".len..]);
    }

    if (std.mem.startsWith(u8, text, "disable")) {
        return hasExpectedSuffix(text["disable".len..]);
    }

    return false;
}

fn hasExpectedSuffix(value: []const u8) bool {
    var text = value;
    if (std.mem.startsWith(u8, text, "-line")) {
        text = text["-line".len..];
    } else if (std.mem.startsWith(u8, text, "-next-line")) {
        text = text["-next-line".len..];
    }

    if (text.len == 0) return true;
    return text[0] == ':' or isWhitespace(text[0]);
}

fn trimLeftWhitespace(value: []const u8) []const u8 {
    var index: usize = 0;
    while (index < value.len and isWhitespace(value[index])) : (index += 1) {}
    return value[index..];
}

fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\t' or char == '\r' or char == '\n';
}
