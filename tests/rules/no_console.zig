const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-console for console member usage" {
    const source =
        \\console.log(value);
        \\console.log;
        \\console.log = value;
        \\delete console.log;
        \\console["log"](value);
        \\console[`log`](value);
        \\console[`lo${suffix}`](value);
        \\console.log?.(value);
        \\console?.log(value);
        \\console?.["log"](value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 10), helpers.countRule(result, lint.rules.no_console.id));
}

test "allows configured no-console methods" {
    const source =
        \\console.warn(value);
        \\console.warn;
        \\console.warn = value;
        \\console["error"](value);
        \\console[`warn`](value);
        \\console[`wa${suffix}`](value);
        \\console.log(value);
    ;

    var allow = (lint.Options{}).no_console_allow;
    try std.testing.expect(allow.enable("warn"));
    try std.testing.expect(allow.enable("error"));

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console_allow = allow,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_console.id));
}

test "supports configured no-console custom method names" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"todo\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-console", config.value);
    options.no_unused_vars = false;
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\console.todo(value);
        \\console["todo"](value);
        \\console.log(value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_console.id));
}

test "does not report no-console for shadowed console" {
    const source =
        \\function local(console) {
        \\  console.log(value);
        \\  console.log = value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_console.id));
}

test "can disable no-console" {
    const source =
        \\console.log(value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_console.id));
}
