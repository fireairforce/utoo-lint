const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_prefer_resource_from_huamei = true;
    return options;
}

test "reports @alipay/ant/prefer-resource-from-huamei for external resource urls" {
    const source =
        \\const png = "https://cdn.example.com/assets/banner.png";
        \\const afts = "https://cdn.example.com/afts/img/abc";
        \\const webp = "http://cdn.example.com/static/icon.webp?x=1";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.alipay_ant_prefer_resource_from_huamei.id));
    try std.testing.expectEqualStrings(
        "静态资源(https://cdn.example.com/assets/banner.png)推荐使用画眉平台进行上传使用(https://huamei.antgroup-inc.cn/my/space).",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "allows @alipay/ant/prefer-resource-from-huamei allowed keywords and non resource urls" {
    const source =
        \\const huamei = "https://huamei.example.com/assets/banner.png";
        \\const mars = "https://cdn.example.com/mars/banner.png";
        \\const graph = "https://gw.alipayobjects.com/graph_jupiter/afts/img/foo";
        \\const jpg = "https://cdn.example.com/assets/banner.jpg";
        \\const local = "/assets/banner.png";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_resource_from_huamei.id));
}

test "can disable @alipay/ant/prefer-resource-from-huamei" {
    const source = "const png = \"https://cdn.example.com/assets/banner.png\";\n";
    var options = optionsOnly();
    options.alipay_ant_prefer_resource_from_huamei = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_resource_from_huamei.id));
}
