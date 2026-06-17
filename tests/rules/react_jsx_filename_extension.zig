const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports react/jsx-filename-extension for JSX in disallowed extensions" {
    const source =
        \\const view = <div />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.mjs", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_jsx_filename_extension.id));
    try std.testing.expect(hasMessage(result, "JSX not allowed in files with extension '.mjs'"));
    try std.testing.expect(!helpers.hasRule(result, "parse"));
}

test "reports react/jsx-filename-extension for JSX fragments" {
    const source =
        \\const view = <></>;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cts", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_jsx_filename_extension.id));
    try std.testing.expect(hasMessage(result, "JSX not allowed in files with extension '.cts'"));
    try std.testing.expect(!helpers.hasRule(result, "parse"));
}

test "reports react/jsx-filename-extension only once per file" {
    const source =
        \\const one = <div />;
        \\const two = <span />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.react_jsx_filename_extension.id));
    try std.testing.expect(!helpers.hasRule(result, "parse"));
}

test "allows react/jsx-filename-extension for fishlint allowed extensions" {
    const source =
        \\const view = <div />;
    ;

    var js_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer js_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(js_result, lint.rules.react_jsx_filename_extension.id));
    try std.testing.expect(!helpers.hasRule(js_result, "parse"));

    var jsx_result = try lint.lintSource(std.testing.allocator, source, "fixture.jsx", baseOptions());
    defer jsx_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(jsx_result, lint.rules.react_jsx_filename_extension.id));
    try std.testing.expect(!helpers.hasRule(jsx_result, "parse"));

    var ts_result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", baseOptions());
    defer ts_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(ts_result, lint.rules.react_jsx_filename_extension.id));
    try std.testing.expect(!helpers.hasRule(ts_result, "parse"));

    var tsx_result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", baseOptions());
    defer tsx_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(tsx_result, lint.rules.react_jsx_filename_extension.id));
    try std.testing.expect(!helpers.hasRule(tsx_result, "parse"));
}

test "supports configured react/jsx-filename-extension extensions" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"extensions\":[\".tsx\"]}]",
        .{},
    );
    defer config.deinit();

    var options = baseOptions();
    try options.setByRuleConfigValue("react/jsx-filename-extension", config.value);

    const source =
        \\const view = <div />;
    ;

    var js_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer js_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(js_result, lint.rules.react_jsx_filename_extension.id));
    try std.testing.expect(hasMessage(js_result, "JSX not allowed in files with extension '.js'"));
    try std.testing.expect(!helpers.hasRule(js_result, "parse"));

    var tsx_result = try lint.lintSource(std.testing.allocator, source, "fixture.tsx", options);
    defer tsx_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(tsx_result, lint.rules.react_jsx_filename_extension.id));
    try std.testing.expect(!helpers.hasRule(tsx_result, "parse"));
}

test "preserves parser diagnostics when JSX fallback still fails" {
    const source =
        \\const view = <div;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(helpers.hasRule(result, "parse"));
}

test "can disable react/jsx-filename-extension" {
    const source =
        \\const view = <div />;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.mjs", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .react_jsx_filename_extension = false,
        .react_jsx_uses_react = false,
        .react_jsx_uses_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.react_jsx_filename_extension.id));
    try std.testing.expect(!helpers.hasRule(result, "parse"));
}

fn baseOptions() lint.Options {
    return .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .react_jsx_uses_react = false,
        .react_jsx_uses_vars = false,
    };
}

fn hasMessage(result: lint.Result, expected: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.react_jsx_filename_extension.id) and
            std.mem.eql(u8, diagnostic.message, expected))
        {
            return true;
        }
    }
    return false;
}
