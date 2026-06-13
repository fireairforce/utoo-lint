const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @alipay/spmLint/valid-manual-click invalid calls" {
    const source =
        \\tracert.click();
        \\tracert.click({a:1});
        \\tracert.click(1);
        \\tracert.click(undefined);
        \\tracert.click(null);
        \\tracert.click('d1','a');
        \\tracert.click('d1',{a:1},'b');
        \\tracert.click('c2.d1',{a:1},{'b':1},'c');
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .alipay_spmlint_use_labeled_spm = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 10), helpers.countRule(result, lint.rules.alipay_spmlint_valid_manual_click.id));
    try std.testing.expectEqualStrings("函数 click 需要传递参数", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("函数 click 第 1 参数类型为spmId", result.diagnostics[1].message);
    try std.testing.expectEqualStrings("点击埋点 spmId 格式应为 a.b.c.d、c.d", result.diagnostics[5].message);
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "allows @alipay/spmLint/valid-manual-click valid calls" {
    const source =
        \\tracert.click('c1.d1',{a:1},{b:1},{c:1});
        \\var x = ''; tracert.click(`${x}`,{a:1},{b:1},{c:1});
        \\tracert.click('c1.d1');
        \\this.tracert.click('c1.d1');
        \\this.$tracert.click('c1.d1');
        \\this.Tracert.click('c1.d1');
        \\Tracert.click('c1.d1');
        \\window.Tracert.click('c1.d1');
        \\tracert.click(a);
        \\tracert.click(a ? "d1" : "c2");
        \\tracert.click('c1.d1',{a:1});
        \\tracert.click('c1.d1',a);
        \\tracert.click('c1.d1',{a:1},{b:2});
        \\tracert.click('c1.d1',a,b);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .alipay_spmlint_use_labeled_spm = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_spmlint_valid_manual_click.id));
}

test "can disable @alipay/spmLint/valid-manual-click" {
    const source =
        \\tracert.click();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .alipay_spmlint_use_labeled_spm = false,
        .alipay_spmlint_valid_manual_click = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_spmlint_valid_manual_click.id));
}
