const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "dot-notation";

pub const Options = struct {
    rule_id: []const u8 = id,
    severity: core.Severity = .warning,
    allow_keywords: bool = true,
    allow_pattern: core.DotNotationAllowPattern = .{},
};

pub fn check(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkWithOptions(allocator, diagnostics, tree, member, index, .{});
}

pub fn checkWithOptions(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    member: ast.MemberExpression,
    index: ast.NodeIndex,
    options: Options,
) Allocator.Error!void {
    if (!member.computed or member.property == .null) return;

    const property_name = staticPropertyName(tree, member.property) orelse return;
    if (!isAsciiIdentifierName(property_name)) return;
    if (!options.allow_keywords and isKeyword(property_name)) return;
    if (isAllowedByPattern(property_name, options.allow_pattern)) return;

    const span = tree.span(index);
    const message = try std.fmt.allocPrint(allocator, "['{s}'] is better written in dot notation.", .{property_name});
    defer allocator.free(message);

    if (wouldDiscardComment(tree, member, span)) {
        try core.addDiagnostic(
            allocator,
            diagnostics,
            options.severity,
            options.rule_id,
            message,
            span,
        );
        return;
    }

    const prefix = if (member.optional)
        "?."
    else if (isDecimalIntegerObject(tree, member.object))
        " ."
    else
        ".";
    const trailing_space = span.end < tree.source.len and isIdentifierPart(tree.source[span.end]);
    const replacement = try std.fmt.allocPrint(
        allocator,
        "{s}{s}{s}",
        .{ prefix, property_name, if (trailing_space) " " else "" },
    );
    defer allocator.free(replacement);

    try core.addDiagnosticWithFix(
        allocator,
        diagnostics,
        options.severity,
        options.rule_id,
        message,
        span,
        .{
            .span = .{ .start = tree.span(member.object).end, .end = span.end },
            .replacement = replacement,
        },
    );
}

fn wouldDiscardComment(tree: *const ast.Tree, member: ast.MemberExpression, span: ast.Span) bool {
    const replaced_start = tree.span(member.object).end;
    for (tree.comments) |comment| {
        if (comment.span.start >= replaced_start and comment.span.end <= span.end) return true;
    }
    return false;
}

fn isDecimalIntegerObject(tree: *const ast.Tree, index: ast.NodeIndex) bool {
    const literal = switch (tree.data(index)) {
        .numeric_literal => |literal| literal,
        else => return false,
    };
    if (literal.kind != .decimal) return false;

    const raw = tree.string(literal.raw);
    if (std.mem.eql(u8, raw, "0")) return true;
    if (raw.len == 0 or !std.ascii.isDigit(raw[0])) return false;

    if (raw[0] == '0') {
        var seen_non_octal_digit = false;
        for (raw[1..]) |char| {
            if (!std.ascii.isDigit(char)) return false;
            if (char == '8' or char == '9') seen_non_octal_digit = true;
        }
        return seen_non_octal_digit;
    }

    if (raw[0] < '1' or raw[0] > '9') return false;
    var previous_underscore = false;
    for (raw[1..]) |char| {
        if (char == '_') {
            if (previous_underscore) return false;
            previous_underscore = true;
            continue;
        }
        if (!std.ascii.isDigit(char)) return false;
        previous_underscore = false;
    }
    return !previous_underscore;
}

fn staticPropertyName(tree: *const ast.Tree, index: ast.NodeIndex) ?[]const u8 {
    return switch (tree.data(index)) {
        .string_literal => |literal| tree.string(literal.value),
        .template_literal => |literal| templateStringValue(tree, literal),
        else => null,
    };
}

fn isAllowedByPattern(name: []const u8, pattern: core.DotNotationAllowPattern) bool {
    const custom_pattern = pattern.pattern() orelse return false;
    if (std.mem.eql(u8, custom_pattern, "^[a-z]+(_[a-z]+)+$")) return isLowerSnakeCase(name);
    return matchesPattern(name, custom_pattern);
}

fn isLowerSnakeCase(name: []const u8) bool {
    var seen_underscore = false;
    var previous_underscore = false;

    for (name, 0..) |char, index| {
        if (char == '_') {
            if (index == 0 or previous_underscore) return false;
            seen_underscore = true;
            previous_underscore = true;
            continue;
        }
        if (!std.ascii.isLower(char)) return false;
        previous_underscore = false;
    }

    return seen_underscore and !previous_underscore;
}

fn matchesPattern(value: []const u8, pattern: []const u8) bool {
    var start: usize = 0;
    while (start <= pattern.len) {
        const remainder = pattern[start..];
        const separator = std.mem.indexOfScalar(u8, remainder, '|');
        const end = if (separator) |offset| start + offset else pattern.len;
        if (matchesAlternative(value, pattern[start..end])) return true;
        if (separator == null) break;
        start = end + 1;
    }
    return false;
}

fn matchesAlternative(value: []const u8, pattern: []const u8) bool {
    const anchored_start = std.mem.startsWith(u8, pattern, "^");
    const anchored_end = std.mem.endsWith(u8, pattern, "$");
    const body_start: usize = if (anchored_start) 1 else 0;
    const body_end = if (anchored_end and pattern.len > body_start) pattern.len - 1 else pattern.len;
    const body = pattern[body_start..body_end];

    if (std.mem.indexOf(u8, body, ".*") != null) {
        return matchesWildcardSequence(value, body, anchored_start, anchored_end);
    }
    if (anchored_start and anchored_end) return std.mem.eql(u8, value, body);
    if (anchored_start) return std.mem.startsWith(u8, value, body);
    if (anchored_end) return std.mem.endsWith(u8, value, body);
    return std.mem.indexOf(u8, value, body) != null;
}

fn matchesWildcardSequence(value: []const u8, pattern: []const u8, anchored_start: bool, anchored_end: bool) bool {
    var value_offset: usize = 0;
    var pattern_offset: usize = 0;
    var part_index: usize = 0;

    while (pattern_offset <= pattern.len) : (part_index += 1) {
        const remainder = pattern[pattern_offset..];
        const wildcard = std.mem.indexOf(u8, remainder, ".*");
        const part_end = if (wildcard) |offset| pattern_offset + offset else pattern.len;
        const part = pattern[pattern_offset..part_end];

        if (part.len > 0) {
            if (part_index == 0 and anchored_start) {
                if (!std.mem.startsWith(u8, value[value_offset..], part)) return false;
                value_offset += part.len;
            } else {
                const found = std.mem.indexOf(u8, value[value_offset..], part) orelse return false;
                value_offset += found + part.len;
            }
        }

        if (wildcard == null) break;
        pattern_offset = part_end + 2;
    }

    if (!anchored_end) return true;
    const suffix_start = lastWildcardPartStart(pattern);
    return std.mem.endsWith(u8, value, pattern[suffix_start..]);
}

fn lastWildcardPartStart(pattern: []const u8) usize {
    var offset: usize = 0;
    var start: usize = 0;
    while (offset < pattern.len) {
        const wildcard = std.mem.indexOf(u8, pattern[offset..], ".*") orelse break;
        start = offset + wildcard + 2;
        offset = start;
    }
    return start;
}

fn templateStringValue(tree: *const ast.Tree, literal: ast.TemplateLiteral) ?[]const u8 {
    if (literal.expressions.len != 0) return null;

    const quasis = tree.extra(literal.quasis);
    if (quasis.len == 0) return "";

    return switch (tree.data(quasis[0])) {
        .template_element => |element| tree.string(element.cooked),
        else => null,
    };
}

fn isAsciiIdentifierName(name: []const u8) bool {
    if (name.len == 0) return false;
    if (!isIdentifierStart(name[0])) return false;

    for (name[1..]) |char| {
        if (!isIdentifierPart(char)) return false;
    }
    return true;
}

fn isIdentifierStart(char: u8) bool {
    return std.ascii.isAlphabetic(char) or char == '_' or char == '$';
}

fn isIdentifierPart(char: u8) bool {
    return isIdentifierStart(char) or std.ascii.isDigit(char);
}

fn isKeyword(name: []const u8) bool {
    const keywords = [_][]const u8{
        "abstract",
        "boolean",
        "break",
        "byte",
        "case",
        "catch",
        "char",
        "class",
        "const",
        "continue",
        "debugger",
        "default",
        "delete",
        "do",
        "double",
        "else",
        "enum",
        "export",
        "extends",
        "false",
        "final",
        "finally",
        "float",
        "for",
        "function",
        "goto",
        "if",
        "implements",
        "import",
        "in",
        "instanceof",
        "int",
        "interface",
        "long",
        "native",
        "new",
        "null",
        "package",
        "private",
        "protected",
        "public",
        "return",
        "short",
        "static",
        "super",
        "switch",
        "synchronized",
        "this",
        "throw",
        "throws",
        "transient",
        "true",
        "try",
        "typeof",
        "var",
        "void",
        "volatile",
        "while",
        "with",
    };

    for (keywords) |keyword| {
        if (std.mem.eql(u8, name, keyword)) return true;
    }
    return false;
}
