const std = @import("std");
const parser = @import("parser");
const core = @import("../core.zig");

const ast = parser.ast;
const Allocator = std.mem.Allocator;

pub const id = "@alipay/ant/disallow-typos";

const Typo = struct {
    right: []const u8,
    msg: []const u8 = "",
    matcher: Matcher,
};

const Matcher = union(enum) {
    followed_by_punctuation_or_end: []const []const u8,
    followed_by_non_punctuation: []const []const u8,
    contains_any: []const []const u8,
    contains_with_whitespace_between: struct { left: []const u8, right: []const u8 },
    receipt,
};

const typos = [_]Typo{
    .{ .right = "请稍候", .matcher = .{ .followed_by_punctuation_or_end = &.{ "请稍后", "请稍後" } } },
    .{ .right = "請稍候", .matcher = .{ .followed_by_punctuation_or_end = &.{ "請稍后", "請稍後" } } },
    .{ .right = "稍候", .matcher = .{ .followed_by_punctuation_or_end = &.{ "稍后", "稍後" } } },
    .{ .right = "請稍後", .matcher = .{ .followed_by_non_punctuation = &.{"請稍候"} } },
    .{ .right = "请稍后", .matcher = .{ .followed_by_non_punctuation = &.{"请稍候"} } },
    .{ .right = "稍后", .matcher = .{ .followed_by_non_punctuation = &.{"稍候"} } },
    .{
        .right = "登录",
        .msg = "。注意台湾地区是`『登入』`。",
        .matcher = .{ .contains_with_whitespace_between = .{ .left = "登", .right = "陆" } },
    },
    .{
        .right = "登錄",
        .msg = "。注意台湾地区是`『登入』`。",
        .matcher = .{ .contains_with_whitespace_between = .{ .left = "登", .right = "陸" } },
    },
    .{
        .right = "账号",
        .msg = "。注意台湾地区使用 `帳号`",
        .matcher = .{ .contains_any = &.{"帐号"} },
    },
    .{
        .right = "账单",
        .msg = "。注意台湾地区是『`帳`單』香港地区是『`賬`單』",
        .matcher = .{ .contains_any = &.{"帐单"} },
    },
    .{ .right = "账户", .matcher = .{ .contains_any = &.{"帐户"} } },
    .{ .right = "賬户", .matcher = .{ .contains_any = &.{"帳户"} } },
    .{ .right = "提醒方式", .matcher = .{ .contains_any = &.{"提醒渠道"} } },
    .{ .right = "即时消息", .matcher = .{ .contains_any = &.{"及时消息"} } },
    .{ .right = "到账时间", .matcher = .{ .contains_any = &.{"入账时间"} } },
    .{
        .right = "凭证",
        .msg = "。涉及付款、转账的操作，最后成功生成的单据为“凭证”，一般产品操作成功生成的单据，可视情况使用“详单”。",
        .matcher = .receipt,
    },
    .{ .right = "转账", .matcher = .{ .contains_any = &.{"转钱"} } },
};

pub fn checkStringLiteral(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.StringLiteral,
    index: ast.NodeIndex,
) Allocator.Error!void {
    try checkText(allocator, diagnostics, tree.string(literal.value), tree.span(index));
}

pub fn checkTemplateLiteral(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    tree: *const ast.Tree,
    literal: ast.TemplateLiteral,
) Allocator.Error!void {
    for (tree.extra(literal.quasis)) |quasi_index| {
        const span = tree.span(quasi_index);
        if (span.start > span.end or span.end > tree.source.len) continue;

        try checkText(allocator, diagnostics, tree.source[span.start..span.end], span);
    }
}

fn checkText(
    allocator: Allocator,
    diagnostics: *core.DiagnosticList,
    value: []const u8,
    span: ast.Span,
) Allocator.Error!void {
    const trimmed = std.mem.trim(u8, value, " \t\r\n");

    for (typos) |typo| {
        if (!matches(trimmed, typo.matcher)) continue;

        try core.addDiagnosticFmt(
            allocator,
            diagnostics,
            .@"error",
            id,
            span,
            "影响用户体验的错别字 `{s}`，应该是 `{s}`{s}",
            .{ trimmed, typo.right, typo.msg },
        );
        return;
    }
}

fn matches(value: []const u8, matcher: Matcher) bool {
    return switch (matcher) {
        .followed_by_punctuation_or_end => |needles| containsFollowedByPunctuationOrEnd(value, needles),
        .followed_by_non_punctuation => |needles| containsFollowedByNonPunctuation(value, needles),
        .contains_any => |needles| containsAny(value, needles),
        .contains_with_whitespace_between => |parts| containsWithWhitespaceBetween(value, parts.left, parts.right),
        .receipt => std.mem.indexOf(u8, value, "回单") != null and std.mem.indexOf(u8, value, "电子回单") == null,
    };
}

fn containsAny(value: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (std.mem.indexOf(u8, value, needle) != null) return true;
    }
    return false;
}

fn containsFollowedByPunctuationOrEnd(value: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        var start: usize = 0;
        while (std.mem.indexOfPos(u8, value, start, needle)) |index| {
            const after = index + needle.len;
            if (after == value.len or startsWithBoundaryPunctuation(value[after..])) return true;
            start = after;
        }
    }
    return false;
}

fn containsFollowedByNonPunctuation(value: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        var start: usize = 0;
        while (std.mem.indexOfPos(u8, value, start, needle)) |index| {
            const after = index + needle.len;
            if (after < value.len and !startsWithBoundaryPunctuation(value[after..])) return true;
            start = after;
        }
    }
    return false;
}

fn containsWithWhitespaceBetween(value: []const u8, left: []const u8, right: []const u8) bool {
    var start: usize = 0;
    while (std.mem.indexOfPos(u8, value, start, left)) |index| {
        var after_left = index + left.len;
        while (after_left < value.len and isAsciiWhitespace(value[after_left])) : (after_left += 1) {}
        if (std.mem.startsWith(u8, value[after_left..], right)) return true;
        start = index + left.len;
    }
    return false;
}

fn startsWithBoundaryPunctuation(value: []const u8) bool {
    return std.mem.startsWith(u8, value, ".") or
        std.mem.startsWith(u8, value, "。") or
        std.mem.startsWith(u8, value, "!") or
        std.mem.startsWith(u8, value, "！") or
        std.mem.startsWith(u8, value, ",") or
        std.mem.startsWith(u8, value, "，") or
        std.mem.startsWith(u8, value, "?") or
        std.mem.startsWith(u8, value, "？");
}

fn isAsciiWhitespace(char: u8) bool {
    return char == ' ' or char == '\t' or char == '\r' or char == '\n' or char == '\x0b' or char == '\x0c';
}
