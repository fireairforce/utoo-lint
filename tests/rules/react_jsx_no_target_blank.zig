const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/jsx-no-target-blank for external and dynamic links without noreferrer" {
    const source =
        \\const external = <a href="https://example.com" target="_blank" />;
        \\const protocolRelative = <a href="//example.com" target="_blank" rel="noopener" />;
        \\const dynamic = <a href={url} target="_blank" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .jsx_a11y_anchor_has_content = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.react_jsx_no_target_blank.id));
    try std.testing.expectEqualStrings(
        "Using target=\"_blank\" without rel=\"noreferrer\" (which implies rel=\"noopener\") is a security risk in older browsers: see https://mathiasbynens.github.io/rel-noopener/#recommendations",
        result.diagnostics[0].message,
    );
}

test "allows secure rel non-external links and non-anchor elements" {
    const source =
        \\const secure = <a href="https://example.com" target="_blank" rel="noopener noreferrer" />;
        \\const relative = <a href="/docs" target="_blank" />;
        \\const button = <button href="https://example.com" target="_blank" />;
        \\const conditional = <a href={url} target={open ? "_blank" : "_self"} rel={open ? "noreferrer" : ""} />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_no_target_blank.id));
}

test "supports configured react/jsx-no-target-blank allowReferrer" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowReferrer\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("react/jsx-no-target-blank", config.value);
    options.eol_last = false;
    options.jsx_a11y_anchor_has_content = false;
    options.no_undef = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\const noopener = <a href="https://example.com" target="_blank" rel="noopener" />;
        \\const missing = <a href="https://example.com" target="_blank" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_jsx_no_target_blank.id));
}

test "supports configured react/jsx-no-target-blank enforceDynamicLinks never" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"enforceDynamicLinks\":\"never\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("react/jsx-no-target-blank", config.value);
    options.eol_last = false;
    options.jsx_a11y_anchor_has_content = false;
    options.no_undef = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\const dynamic = <a href={url} target="_blank" />;
        \\const external = <a href="https://example.com" target="_blank" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_jsx_no_target_blank.id));
}

test "can disable react/jsx-no-target-blank" {
    const source =
        \\const link = <a href="https://example.com" target="_blank" />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", .{
        .eol_last = false,
        .react_jsx_no_target_blank = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_no_target_blank.id));
}
