const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_prefer_managed_resource = true;
    return options;
}

test "reports @alipay/ant/prefer-managed-resource for external resource urls" {
    const source =
        \\const png = "https://cdn.example.com/assets/banner.png";
        \\const managedPath = "https://cdn.example.com/managed/img/abc";
        \\const webp = "http://cdn.example.com/static/icon.webp?x=1";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.alipay_ant_prefer_managed_resource.id));
    try std.testing.expectEqualStrings(
        "静态资源(https://cdn.example.com/assets/banner.png)推荐使用资源管理平台进行上传使用(https://assets.example.com/space).",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqual(.warning, result.diagnostics[0].severity);
}

test "allows @alipay/ant/prefer-managed-resource allowed keywords and non resource urls" {
    const source =
        \\const resourceHub = "https://resource-hub.example.com/assets/banner.png";
        \\const mars = "https://cdn.example.com/mars/banner.png";
        \\const graph = "https://static.example.com/managed_asset/managed/img/foo";
        \\const jpg = "https://cdn.example.com/assets/banner.jpg";
        \\const local = "/assets/banner.png";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_managed_resource.id));
}

test "can disable @alipay/ant/prefer-managed-resource" {
    const source = "const png = \"https://cdn.example.com/assets/banner.png\";\n";
    var options = optionsOnly();
    options.alipay_ant_prefer_managed_resource = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_managed_resource.id));
}
