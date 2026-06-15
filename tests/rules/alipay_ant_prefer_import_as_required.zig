const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_prefer_import_as_required = true;
    return options;
}

test "reports @alipay/ant/prefer-import-as-required for default and namespace checked imports" {
    const source =
        \\import lodashEs from 'lodash-es';
        \\import * as stdlib from '@example/stdlib';
        \\import components, { Button } from '@example/content-components';
        \\import { debounce } from 'lodash-es';
        \\import other from 'other-package';
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.alipay_ant_prefer_import_as_required.id));
    try std.testing.expectEqualStrings("使用按需引入以减小构建包体积: lodash-es.", result.diagnostics[0].message);
    try std.testing.expectEqual(.@"error", result.diagnostics[0].severity);
}

test "allows @alipay/ant/prefer-import-as-required named and unchecked imports" {
    const source =
        \\import { debounce } from 'lodash-es';
        \\import { Button } from '@example/content-components';
        \\import other from 'other-package';
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_import_as_required.id));
}

test "can disable @alipay/ant/prefer-import-as-required" {
    const source = "import lodashEs from 'lodash-es';\n";
    var options = optionsOnly();
    options.alipay_ant_prefer_import_as_required = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_import_as_required.id));
}
