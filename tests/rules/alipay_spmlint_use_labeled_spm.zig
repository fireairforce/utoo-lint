const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @alipay/spmLint/use-labeled-spm for manual tracert calls" {
    const source =
        \\this.tracert.expo('c1');
        \\this.$tracert.click('c1.d1');
        \\window.Tracert.logPv();
        \\tracert.expo('c1');
        \\Tracert.click('c1.d1');
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.alipay_spmlint_use_labeled_spm.id));
    try std.testing.expectEqualStrings("请优先使用声明式埋点", result.diagnostics[0].message);
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "does not report @alipay/spmLint/use-labeled-spm for unrelated calls" {
    const source =
        \\a.expo();
        \\a.logPv();
        \\a.click();
        \\expo();
        \\logPv();
        \\click();
        \\this.tracert.set();
        \\this['tracert'].expo('c1');
        \\this.tracert['expo']('c1');
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_spmlint_use_labeled_spm.id));
}

test "can disable @alipay/spmLint/use-labeled-spm" {
    const source =
        \\this.tracert.expo('c1');
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .alipay_spmlint_use_labeled_spm = false,
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_spmlint_use_labeled_spm.id));
}
