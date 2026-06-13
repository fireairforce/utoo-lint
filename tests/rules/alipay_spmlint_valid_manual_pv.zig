const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @alipay/spmLint/valid-manual-pv for invalid logPv first params" {
    const source =
        \\tracert.logPv(null);
        \\tracert.logPv('111');
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .alipay_spmlint_use_labeled_spm = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.alipay_spmlint_valid_manual_pv.id));
    try std.testing.expectEqualStrings("函数 logPv 第一个参数类型为 Object", result.diagnostics[0].message);
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "allows @alipay/spmLint/valid-manual-pv valid logPv usages" {
    const source =
        \\tracert.logPv();
        \\this.tracert.logPv();
        \\this.$tracert.logPv();
        \\this.Tracert.logPv();
        \\window.Tracert.logPv();
        \\Tracert.logPv();
        \\tracert.logPv({a:1});
        \\tracert.logPv({a:1}, {b:2});
        \\tracert.logPv(a);
        \\tracert.logPv(a());
        \\tracert.logPv(a.b);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .alipay_spmlint_use_labeled_spm = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_spmlint_valid_manual_pv.id));
}

test "can disable @alipay/spmLint/valid-manual-pv" {
    const source =
        \\tracert.logPv(null);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .alipay_spmlint_use_labeled_spm = false,
        .alipay_spmlint_valid_manual_pv = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_spmlint_valid_manual_pv.id));
}
