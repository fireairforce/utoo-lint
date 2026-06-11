const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-control-regex";

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.RegExpLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    var control_chars: std.ArrayList(u8) = .empty;
    defer control_chars.deinit(allocator);

    try collectControlChars(allocator, tree.string(literal.pattern), &control_chars);
    if (control_chars.items.len == 0) return;

    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        tree.span(index),
        "Unexpected control character(s) in regular expression: {s}.",
        .{control_chars.items},
    );
}

fn collectControlChars(
    allocator: Allocator,
    pattern: []const u8,
    out: *std.ArrayList(u8),
) Allocator.Error!void {
    var index: usize = 0;
    while (index < pattern.len) {
        const char = pattern[index];

        if (char < 0x20) {
            try appendControlChar(allocator, out, char);
            index += 1;
            continue;
        }

        if (char == '\\' and index + 1 < pattern.len) {
            switch (pattern[index + 1]) {
                'x' => {
                    if (index + 3 < pattern.len) {
                        if (parseFixedHex(pattern[index + 2 .. index + 4])) |value| {
                            if (value <= 0x1f) try appendControlChar(allocator, out, value);
                        }
                        index += 4;
                        continue;
                    }
                },
                'u' => {
                    if (parseUnicodeEscape(pattern, &index)) |value| {
                        if (value <= 0x1f) try appendControlChar(allocator, out, value);
                        continue;
                    }
                },
                else => {},
            }
        }

        index += 1;
    }
}

fn parseUnicodeEscape(pattern: []const u8, index: *usize) ?u8 {
    const start = index.*;
    if (start + 1 >= pattern.len or pattern[start] != '\\' or pattern[start + 1] != 'u') return null;

    if (start + 2 < pattern.len and pattern[start + 2] == '{') {
        var cursor = start + 3;
        var value: u21 = 0;
        var saw_digit = false;

        while (cursor < pattern.len and pattern[cursor] != '}') : (cursor += 1) {
            const digit = hexValue(pattern[cursor]) orelse return null;
            saw_digit = true;
            value = value * 16 + digit;
            if (value > 0x10ffff) return null;
        }

        if (!saw_digit or cursor >= pattern.len or pattern[cursor] != '}') return null;

        index.* = cursor + 1;
        if (value <= 0xff) return @intCast(value);
        return null;
    }

    if (start + 5 >= pattern.len) return null;
    const value = parseFixedHex(pattern[start + 2 .. start + 6]) orelse return null;
    index.* = start + 6;
    return value;
}

fn parseFixedHex(bytes: []const u8) ?u8 {
    var value: u16 = 0;
    for (bytes) |byte| {
        const digit = hexValue(byte) orelse return null;
        value = value * 16 + digit;
    }

    if (value > 0xff) return null;
    return @intCast(value);
}

fn hexValue(byte: u8) ?u8 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'f' => byte - 'a' + 10,
        'A'...'F' => byte - 'A' + 10,
        else => null,
    };
}

fn appendControlChar(
    allocator: Allocator,
    out: *std.ArrayList(u8),
    value: u8,
) Allocator.Error!void {
    if (out.items.len > 0) try out.appendSlice(allocator, ", ");
    const escaped = try std.fmt.allocPrint(allocator, "\\x{x:0>2}", .{value});
    defer allocator.free(escaped);
    try out.appendSlice(allocator, escaped);
}
