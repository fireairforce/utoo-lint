const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_prefer_elseif_end_with_else = true;
    return options;
}

test "reports @alipay/ant/prefer-elseif-end-with-else for else-if chains without final else" {
    const source =
        \\function test() {
        \\  if (a) {
        \\    runA();
        \\  } else if (b) {
        \\    runB();
        \\  }
        \\
        \\  if (one) {
        \\    return 1;
        \\  } else if (two) {
        \\    return 2;
        \\  } else if (three) {
        \\    runThree();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.alipay_ant_prefer_elseif_end_with_else.id));
    try std.testing.expectEqualStrings("Prefer elseif end with else.", result.diagnostics[0].message);
    try std.testing.expectEqual(.@"error", result.diagnostics[0].severity);
}

test "allows @alipay/ant/prefer-elseif-end-with-else when branches return or final else exists" {
    const source =
        \\function test() {
        \\  if (a) {
        \\    return 1;
        \\  } else if (b) {
        \\    return 2;
        \\  }
        \\
        \\  if (one) {
        \\    runOne();
        \\  } else if (two) {
        \\    runTwo();
        \\  } else {
        \\    runOther();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_elseif_end_with_else.id));
}

test "can disable @alipay/ant/prefer-elseif-end-with-else" {
    const source =
        \\if (a) {
        \\  runA();
        \\} else if (b) {
        \\  runB();
        \\}
    ;
    var options = optionsOnly();
    options.alipay_ant_prefer_elseif_end_with_else = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_elseif_end_with_else.id));
}
