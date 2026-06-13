const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_no_deprecated_variable = true;
    return options;
}

test "reports @alipay/ant/no-deprecated-variable for ap and AlipayJSBridge member usage" {
    const source =
        \\ap.alert();
        \\AlipayJSBridge.call("toast");
        \\bridge[ap]();
        \\bridge.AlipayJSBridge();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.alipay_ant_no_deprecated_variable.id));
    try std.testing.expectEqualStrings("ap 不推荐使用。强烈建议 使用 my 替代。", result.diagnostics[0].message);
    try std.testing.expectEqual(.@"error", result.diagnostics[0].severity);
}

test "allows @alipay/ant/no-deprecated-variable ordinary members and identifiers" {
    const source =
        \\const ap = createBridge();
        \\my.alert();
        \\bridge.call("toast");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_no_deprecated_variable.id));
}

test "can disable @alipay/ant/no-deprecated-variable" {
    const source = "ap.alert();\n";
    var options = optionsOnly();
    options.alipay_ant_no_deprecated_variable = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_no_deprecated_variable.id));
}
