const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "no-useless-escape";

pub fn checkStringLiteral(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    index: ast.NodeIndex,
) Allocator.Error!void {
    const source = sourceSlice(tree, index) orelse return;
    if (source.len < 2) return;

    const delimiter = source[0];
    try checkStringLike(allocator, diagnostics, source[1 .. source.len - 1], tree.span(index), delimiter, false);
}

pub fn checkTemplateLiteral(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.TemplateLiteral,
) Allocator.Error!void {
    const quasis = tree.extra(literal.quasis);

    for (quasis) |quasi| {
        const source = sourceSlice(tree, quasi) orelse continue;
        try checkStringLike(allocator, diagnostics, source, tree.span(quasi), '`', true);
    }
}

pub fn checkRegExpLiteral(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.RegExpLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkRegExpPattern(
        allocator,
        diagnostics,
        tree.string(literal.pattern),
        tree.span(index),
    );
}

fn checkStringLike(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    source: []const u8,
    span: ast.Span,
    delimiter: u8,
    is_template: bool,
) Allocator.Error!void {
    var offset: usize = 0;

    while (offset < source.len) {
        if (source[offset] != '\\' or offset + 1 >= source.len) {
            offset += 1;
            continue;
        }

        const escaped = source[offset + 1];
        if (!isNecessaryStringEscape(source, offset, escaped, delimiter, is_template)) {
            try addDiagnostic(allocator, diagnostics, span, escaped);
        }

        offset += 2;
    }
}

fn isNecessaryStringEscape(
    source: []const u8,
    offset: usize,
    escaped: u8,
    delimiter: u8,
    is_template: bool,
) bool {
    if (escaped == delimiter or escaped == '\\') return true;

    if (is_template and escaped == '$') {
        return offset + 2 < source.len and source[offset + 2] == '{';
    }

    return switch (escaped) {
        '0'...'9',
        'b',
        'f',
        'n',
        'r',
        't',
        'v',
        'x',
        'u',
        '\n',
        '\r',
        => true,
        else => false,
    };
}

fn checkRegExpPattern(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    pattern: []const u8,
    span: ast.Span,
) Allocator.Error!void {
    var offset: usize = 0;
    var in_class = false;
    var class_start: ?usize = null;

    while (offset < pattern.len) {
        const char = pattern[offset];
        if (char == '[' and !in_class) {
            in_class = true;
            class_start = offset;
        }
        if (char == ']' and in_class) {
            in_class = false;
            class_start = null;
        }

        if (char != '\\' or offset + 1 >= pattern.len) {
            offset += 1;
            continue;
        }

        const escaped = pattern[offset + 1];
        if (!isNecessaryRegExpEscape(pattern, offset, escaped, in_class, class_start)) {
            try addDiagnostic(allocator, diagnostics, span, escaped);
        }

        offset += 2;
    }
}

fn isNecessaryRegExpEscape(
    pattern: []const u8,
    offset: usize,
    escaped: u8,
    in_class: bool,
    class_start: ?usize,
) bool {
    if (std.ascii.isAlphanumeric(escaped)) return true;

    if (in_class) {
        return switch (escaped) {
            '\\',
            ']',
            => true,
            '^' => class_start != null and offset == class_start.? + 1,
            '-' => isEscapedHyphenRangeOperator(pattern, offset, class_start),
            else => false,
        };
    }

    return switch (escaped) {
        '\\',
        '/',
        '^',
        '$',
        '.',
        '*',
        '+',
        '?',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        '|',
        => true,
        else => false,
    };
}

fn isEscapedHyphenRangeOperator(pattern: []const u8, offset: usize, class_start: ?usize) bool {
    const start = class_start orelse return false;
    if (offset <= start + 1) return false;

    var first_element = start + 1;
    if (first_element < pattern.len and pattern[first_element] == '^') first_element += 1;
    if (first_element >= offset) return false;

    const after_escape = offset + 2;
    return after_escape < pattern.len and pattern[after_escape] != ']';
}

fn addDiagnostic(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    span: ast.Span,
    escaped: u8,
) Allocator.Error!void {
    try core.addDiagnosticFmt(
        allocator,
        diagnostics,
        .warning,
        id,
        span,
        "Unnecessary escape character: \\{c}.",
        .{escaped},
    );
}

fn sourceSlice(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    if (index == .null) return null;

    const span = tree.span(index);
    const start: usize = @intCast(span.start);
    const end: usize = @intCast(span.end);

    if (start >= end or end > tree.source.len) return null;
    return tree.source[start..end];
}
