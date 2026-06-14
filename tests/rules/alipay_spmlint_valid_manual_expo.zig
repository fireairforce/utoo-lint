const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @alipay/spmLint/valid-manual-expo invalid calls" {
    const source =
        \\tracert.expo('a1.b1.c1.d1.e1');
        \\Tracert.expo('a1.b1.c1.d1.e1',{});
        \\window.Tracert.expo('a1.b1.c1.d1.e1',{});
        \\tracert.expo();
        \\tracert.expo({a:1});
        \\tracert.expo(1);
        \\tracert.expo(undefined);
        \\tracert.expo(null);
        \\tracert.expo('c1','a');
        \\tracert.expo('c1',{a:1},'b');
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .alipay_spmlint_use_labeled_spm = false,
        .eol_last = false,
        .no_undef = false,
        .no_undefined = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 12), helpers.countRule(result, lint.rules.alipay_spmlint_valid_manual_expo.id));
    try std.testing.expectEqualStrings("曝光埋点 spmId 格式应为 a.b.c?.d、c?.d", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("函数 expo 第 2 参数类型为字符串(曝光方向)", result.diagnostics[2].message);
    try std.testing.expectEqualStrings("函数 expo 需要传递参数", result.diagnostics[5].message);
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "allows @alipay/spmLint/valid-manual-expo valid calls" {
    const source =
        \\Tracert.expo('c1', null, {});
        \\window.Tracert.expo('c1.d1', '', {});
        \\tracert.expo('c1');
        \\this.tracert.expo('c1');
        \\this.$tracert.expo('c1');
        \\this.Tracert.expo('c1');
        \\Tracert.expo('c1');
        \\Tracert.expo('c1', '');
        \\window.Tracert.expo('c1');
        \\tracert.expo(a);
        \\tracert.expo(a ? "c1" : "c2");
        \\tracert.expo('c1',{a:1});
        \\tracert.expo('c1',a);
        \\tracert.expo('c1',{a:1},{b:2});
        \\tracert.expo('c1',a,b);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .alipay_spmlint_use_labeled_spm = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_spmlint_valid_manual_expo.id));
}

test "can disable @alipay/spmLint/valid-manual-expo" {
    const source =
        \\tracert.expo();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .alipay_spmlint_use_labeled_spm = false,
        .alipay_spmlint_valid_manual_expo = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_spmlint_valid_manual_expo.id));
}
