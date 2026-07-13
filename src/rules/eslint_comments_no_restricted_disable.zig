const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "eslint-comments/no-restricted-disable";

const restricted_rule = "no-nested-ternary";

pub fn run(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    restrict_no_nested_ternary: bool,
) Allocator.Error!void {
    if (!restrict_no_nested_ternary) return;

    for (tree.comments) |comment| {
        if (!disablesRestrictedRule(tree.string(comment.value))) continue;
        try core.addDiagnostic(
            allocator,
            diagnostics,
            .warning,
            id,
            "Disabling 'no-nested-ternary' is not allowed.",
            .{ .start = comment.span.start, .end = comment.span.end },
        );
    }
}

fn disablesRestrictedRule(comment: []const u8) bool {
    const trimmed = trimLeftWhitespace(comment);
    const tail = disableDirectiveTail(trimmed) orelse return false;
    const rules = trimDescription(trimWhitespace(tail));
    if (rules.len == 0) return true;

    var cursor: usize = 0;
    while (cursor < rules.len) {
        while (cursor < rules.len and isRuleSeparator(rules[cursor])) : (cursor += 1) {}
        const start = cursor;
        while (cursor < rules.len and !isRuleSeparator(rules[cursor])) : (cursor += 1) {}
        if (start < cursor and std.mem.eql(u8, rules[start..cursor], restricted_rule)) return true;
    }
    return false;
}

fn disableDirectiveTail(value: []const u8) ?[]const u8 {
    const directives = [_][]const u8{
        "eslint-disable-next-line",
        "eslint-disable-line",
        "eslint-disable",
    };

    for (directives) |directive| {
        if (!std.mem.startsWith(u8, value, directive)) continue;
        if (value.len == directive.len) return value[directive.len..];
        if (isWhitespace(value[directive.len])) return value[directive.len..];
    }
    return null;
}

fn trimDescription(value: []const u8) []const u8 {
    if (std.mem.startsWith(u8, value, "--")) return "";
    if (std.mem.indexOf(u8, value, " -- ")) |index| return trimWhitespace(value[0..index]);
    return value;
}

fn trimWhitespace(value: []const u8) []const u8 {
    return trimRightWhitespace(trimLeftWhitespace(value));
}

fn trimLeftWhitespace(value: []const u8) []const u8 {
    var index: usize = 0;
    while (index < value.len and isWhitespace(value[index])) : (index += 1) {}
    return value[index..];
}

fn trimRightWhitespace(value: []const u8) []const u8 {
    var end = value.len;
    while (end > 0 and isWhitespace(value[end - 1])) : (end -= 1) {}
    return value[0..end];
}

fn isRuleSeparator(char: u8) bool {
    return char == ',' or isWhitespace(char);
}

fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\t' or char == '\r' or char == '\n';
}
