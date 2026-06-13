const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @alipay/ant/disallow-typos for string and template literals" {
    const source =
        \\const a = "请稍后";
        \\const b = `登 陆成功`;
        \\const c = `付款回单`;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.alipay_ant_disallow_typos.id));
    try std.testing.expectEqual(.@"error", result.diagnostics[0].severity);
    try std.testing.expectEqualStrings(
        "影响用户体验的错别字 `请稍后`，应该是 `请稍候`",
        result.diagnostics[0].message,
    );
}

test "respects ordered typo patterns and punctuation boundaries" {
    const source =
        \\const a = "请稍候处理";
        \\const b = "请稍候。";
        \\const c = "稍候处理";
        \\const d = "稍候。";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.alipay_ant_disallow_typos.id));
    try std.testing.expectEqualStrings(
        "影响用户体验的错别字 `请稍候处理`，应该是 `请稍后`",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqualStrings(
        "影响用户体验的错别字 `稍候处理`，应该是 `稍后`",
        result.diagnostics[1].message,
    );
}

test "reports configured words and skips electronic receipts" {
    const source =
        \\const a = "帐号";
        \\const b = "帐单";
        \\const c = "提醒渠道";
        \\const d = "及时消息";
        \\const e = "入账时间";
        \\const f = "电子回单";
        \\const g = "转钱";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.alipay_ant_disallow_typos.id));
}

test "does not report @alipay/ant/disallow-typos for accepted wording" {
    const source =
        \\const a = "请稍候。";
        \\const b = "请稍后处理";
        \\const c = "登录";
        \\const d = "账号";
        \\const e = "电子回单";
        \\const f = `登\\n陆`;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_disallow_typos.id));
}

test "can disable @alipay/ant/disallow-typos" {
    const source =
        \\const a = "请稍后";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .alipay_ant_disallow_typos = false,
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_disallow_typos.id));
}
