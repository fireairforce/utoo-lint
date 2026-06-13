const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_no_negative_conditionals = true;
    return options;
}

test "reports @alipay/ant/no-negative-conditionals for negative is identifiers" {
    const source =
        \\const isNotReady = isNotAllowed;
        \\const obj = { isNotReady };
        \\foo.isNotReady;
        \\const isNotification = true;
        \\const isNOT_READY = true;
        \\const isNOTReady = true;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.alipay_ant_no_negative_conditionals.id));
    try std.testing.expectEqualStrings("use `isReady` instead `isNotReady`.", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("use `is_READY` instead `isNOT_READY`.", result.diagnostics[5].message);
    try std.testing.expectEqual(.@"error", result.diagnostics[0].severity);
}

test "allows @alipay/ant/no-negative-conditionals non matching names" {
    const source =
        \\const isNotification = true;
        \\const isnotReady = true;
        \\const wasNotReady = true;
        \\const isNOTReady = true;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_no_negative_conditionals.id));
}

test "can disable @alipay/ant/no-negative-conditionals" {
    const source = "const isNotReady = true;\n";
    var options = optionsOnly();
    options.alipay_ant_no_negative_conditionals = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_no_negative_conditionals.id));
}
