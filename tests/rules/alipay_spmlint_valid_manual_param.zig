const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @alipay/spmLint/valid-manual-param for invalid Tracert.call usages" {
    const source =
        \\Tracert.call();
        \\Tracert.call('logPv', '23');
        \\Tracert.call('expo');
        \\Tracert.call('expo','c2.d33', '', {}, {}, '23');
        \\Tracert.call('expo','a1.b1.c33.d4.e5', '');
        \\Tracert.call('expo','c33', {});
        \\Tracert.call('click');
        \\Tracert.call('click','c33', '3', {}, {});
        \\Tracert.call('click',1);
        \\Tracert.call('click',null);
        \\Tracert.call('click',{});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .alipay_spmlint_use_labeled_spm = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 12), helpers.countRule(result, lint.rules.alipay_spmlint_valid_manual_param.id));
    try std.testing.expectEqualStrings("函数 call 需要传递参数", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("函数 logPv 第 1 参数类型为object", result.diagnostics[1].message);
    try std.testing.expectEqualStrings("曝光埋点 spmId 格式应为 a.b.c?.d、c?.d", result.diagnostics[4].message);
    try std.testing.expectEqualStrings("点击埋点 spmId 格式应为 a.b.c.d、c.d", result.diagnostics[7].message);
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "allows @alipay/spmLint/valid-manual-param valid Tracert.call usages" {
    const source =
        \\Tracert.set('logPv');
        \\Tracert.set({});
        \\Tracert.call('logPv');
        \\Tracert.call('logPv', {});
        \\Tracert.call('expo', 'a1.b1.c1.d1');
        \\Tracert.call('expo','c1');
        \\Tracert.call('click','c1.d2');
        \\Tracert.call('click', 'c1.d1', {}, {}, {});
        \\var a = {}; Tracert.call('click', 'c1.d2', a.b, a.d, a);
        \\var b = () => {}; Tracert.call('click', 'a1.b2.c1.d2', b, b, b);
        \\Tracert.call(a);
        \\Tracert.call('unknown');
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .alipay_spmlint_use_labeled_spm = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_spmlint_valid_manual_param.id));
}

test "can disable @alipay/spmLint/valid-manual-param" {
    const source =
        \\Tracert.call();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .alipay_spmlint_use_labeled_spm = false,
        .alipay_spmlint_valid_manual_param = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_spmlint_valid_manual_param.id));
}
