const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_prefer_catch_unsafe_func_call = true;
    return options;
}

test "reports @alipay/ant/prefer-catch-unsafe-func-call outside try blocks" {
    const source =
        \\decodeURIComponent(value);
        \\localStorage.setItem("key", value);
        \\JSON.parse(value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.alipay_ant_prefer_catch_unsafe_func_call.id));
    try std.testing.expectEqualStrings("`decodeURIComponent`存在无法解析出错可能, 需进行catch处理", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("`localStorage.setItem`存在无法写入报错可能, 需进行catch处理", result.diagnostics[1].message);
    try std.testing.expectEqual(.@"error", result.diagnostics[0].severity);
}

test "allows @alipay/ant/prefer-catch-unsafe-func-call inside try block" {
    const source =
        \\try {
        \\  decodeURIComponent(value);
        \\  localStorage.setItem("key", value);
        \\} catch (error) {
        \\  report(error);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_catch_unsafe_func_call.id));
}

test "can disable @alipay/ant/prefer-catch-unsafe-func-call" {
    const source = "decodeURIComponent(value);\n";
    var options = optionsOnly();
    options.alipay_ant_prefer_catch_unsafe_func_call = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_catch_unsafe_func_call.id));
}
