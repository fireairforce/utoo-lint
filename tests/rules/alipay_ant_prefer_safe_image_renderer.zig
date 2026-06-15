const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.alipay_ant_prefer_safe_image_renderer = true;
    options.parser_semantic_errors = false;
    return options;
}

test "reports @alipay/ant/prefer-safe-image-renderer for variable img src" {
    const source = "const view = <img src={url} />;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.alipay_ant_prefer_safe_image_renderer.id));
    try std.testing.expectEqualStrings(
        "图片链接为变量(包括常量), 请使用safe-image-kit中的`Image|BackgroundImageDiv`组件渲染(避免出现意外空值造成额外非预期请求, 或avif格式图片无法加载等情况): url",
        result.diagnostics[0].message,
    );
    try std.testing.expectEqual(.@"error", result.diagnostics[0].severity);
}

test "reports @alipay/ant/prefer-safe-image-renderer for avif img src" {
    const source = "const view = <img src=\"https://x.test/a.avif\" />;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.alipay_ant_prefer_safe_image_renderer.id));
    try std.testing.expectEqualStrings(
        "图片链接为avif格式, 请使用safe-image-kit中的`Image|BackgroundImageDiv`组件渲染(否则不支持该格式的设备将无法降级): https://x.test/a.avif",
        result.diagnostics[0].message,
    );
}

test "reports @alipay/ant/prefer-safe-image-renderer for background style image props" {
    const source =
        \\const view = <div style={{ backgroundImage: bg, background: "url(a.png)", color: "red" }} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.alipay_ant_prefer_safe_image_renderer.id));
}

test "allows @alipay/ant/prefer-safe-image-renderer legacy lint safe cases" {
    const source =
        \\const png = <img src="https://x.test/a.png" />;
        \\const upper = <Img src={url} />;
        \\const literal = <img src={null} />;
        \\const stringKey = <div style={{ "background": bg }} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_safe_image_renderer.id));
}

test "matches legacy lint template src behavior for @alipay/ant/prefer-safe-image-renderer" {
    const source = "const view = <img src={`https://x.test/a.avif`} />;\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.alipay_ant_prefer_safe_image_renderer.id));
    try std.testing.expect(std.mem.indexOf(u8, result.diagnostics[0].message, "变量(包括常量)") != null);
}

test "can disable @alipay/ant/prefer-safe-image-renderer" {
    const source = "const view = <img src={url} />;\n";
    var options = optionsOnly();
    options.alipay_ant_prefer_safe_image_renderer = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.alipay_ant_prefer_safe_image_renderer.id));
}
