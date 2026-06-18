const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "linebreak-style";

pub const Style = enum {
    unix,
    windows,
};

pub const Options = struct {
    style: Style = .unix,
};

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
) Allocator.Error!void {
    try runWithOptions(allocator, diagnostics, tree, .{});
}

pub fn runWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    options: Options,
) Allocator.Error!void {
    const source = tree.source;
    var index: usize = 0;

    while (findLinebreak(source, index)) |linebreak| {
        if (!linebreakMatchesStyle(linebreak, options.style)) {
            try core.addDiagnostic(
                allocator,
                diagnostics,
                .warning,
                id,
                messageForStyle(options.style),
                .{ .start = @intCast(linebreak.start), .end = @intCast(linebreak.end) },
            );
        }

        index = linebreak.end;
    }
}

const Linebreak = struct {
    start: usize,
    end: usize,
    style: Style,
};

fn findLinebreak(source: []const u8, start: usize) ?Linebreak {
    var index = start;
    while (index < source.len) : (index += 1) {
        if (source[index] == '\n') {
            return .{ .start = index, .end = index + 1, .style = .unix };
        }
        if (source[index] == '\r') {
            if (index + 1 < source.len and source[index + 1] == '\n') {
                return .{ .start = index, .end = index + 2, .style = .windows };
            }
            return .{ .start = index, .end = index + 1, .style = .windows };
        }
    }
    return null;
}

fn linebreakMatchesStyle(linebreak: Linebreak, style: Style) bool {
    return switch (style) {
        .unix => linebreak.style == .unix,
        .windows => linebreak.style == .windows and linebreak.end == linebreak.start + 2,
    };
}

fn messageForStyle(style: Style) []const u8 {
    return switch (style) {
        .unix => "Expected linebreaks to be 'LF' but found 'CRLF'.",
        .windows => "Expected linebreaks to be 'CRLF' but found 'LF'.",
    };
}
