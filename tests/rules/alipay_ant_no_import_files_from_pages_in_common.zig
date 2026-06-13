const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_no_import_files_from_pages_in_common = true;
    return options;
}

test "reports @alipay/ant/no-import-files-from-pages-in-common in src common files" {
    const source =
        \\import pageA from 'smallfish/page-home';
        \\import pageB from '@scope/smallfish-mobile/page-detail';
        \\import ok from 'smallfish/component-card';
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "src/common/foo.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.alipay_ant_no_import_files_from_pages_in_common.id));
    try std.testing.expectEqualStrings(
        "don't import things from src/pages/ while you're in src/common: reading `smallfish/page-home` now.",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqual(.@"error", result.diagnostics[0].severity);
}

test "allows @alipay/ant/no-import-files-from-pages-in-common outside src common" {
    const source = "import pageA from 'smallfish/page-home';\n";

    var result = try lint.lintSource(std.testing.allocator, source, "src/pages/foo.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_no_import_files_from_pages_in_common.id));
}

test "can disable @alipay/ant/no-import-files-from-pages-in-common" {
    const source = "import pageA from 'smallfish/page-home';\n";
    var options = optionsOnly();
    options.alipay_ant_no_import_files_from_pages_in_common = false;

    var result = try lint.lintSource(std.testing.allocator, source, "src/common/foo.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_no_import_files_from_pages_in_common.id));
}
