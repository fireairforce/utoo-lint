const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_no_deprecated_dependence = true;
    return options;
}

test "reports @alipay/ant/no-deprecated-dependence for default deprecated imports" {
    const source =
        \\import { foo } from "@alipay/qiaozhi/utils";
        \\import hooks from "@alipay/ivy-hooks/useFoo";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.alipay_ant_no_deprecated_dependence.id));
    try std.testing.expectEqualStrings("@alipay/qiaozhi/utils 工具库不推荐使用，请使用 @alipay/shandie-utils", result.diagnostics[0].message);
    try std.testing.expectEqual(.@"error", result.diagnostics[0].severity);
}

test "matches fishlint side-effect-only skip for @alipay/ant/no-deprecated-dependence" {
    const source = "import \"@alipay/qiaozhi/utils\";\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_no_deprecated_dependence.id));
}

test "supports ivy @alipay/ant/no-deprecated-dependence packages and whitelist" {
    const source =
        \\import { AError as AErrorAlias } from "@alipay/qiaozhi/utils";
        \\import { Other } from "@alipay/qiaozhi/utils";
        \\import moment from "moment";
    ;
    var options = optionsOnly();
    options.alipay_ant_no_deprecated_dependence_profile = .ivy;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.alipay_ant_no_deprecated_dependence.id));
    try std.testing.expectEqualStrings("@alipay/qiaozhi/utils 工具库不推荐使用，请使用 @alipay/shandie-utils", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("moment 工具库不推荐使用，请使用 dayjs(原依赖包体积过大)", result.diagnostics[1].message);
}

test "supports insurance @alipay/ant/no-deprecated-dependence packages" {
    const source =
        \\import bridge from "@alipay/one-bridge";
        \\import { request } from "@alipay/bx-rpc/path";
    ;
    var options = optionsOnly();
    options.alipay_ant_no_deprecated_dependence_profile = .insurance;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.alipay_ant_no_deprecated_dependence.id));
    try std.testing.expectEqualStrings("@alipay/one-bridge 工具库不推荐使用，请使用 babyfish", result.diagnostics[0].message);
}

test "can disable @alipay/ant/no-deprecated-dependence" {
    const source = "import { foo } from \"@alipay/qiaozhi/utils\";\n";
    var options = optionsOnly();
    options.alipay_ant_no_deprecated_dependence = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_no_deprecated_dependence.id));
}
