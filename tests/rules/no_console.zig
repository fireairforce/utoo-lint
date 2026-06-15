const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-console for console calls" {
    const source =
        \\console.log(value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(helpers.hasRule(result, lint.rules.no_console.id));
}

test "allows configured no-console methods" {
    const source =
        \\console.warn(value);
        \\console["error"](value);
        \\console.log(value);
    ;

    var allow = (lint.Options{}).no_console_allow;
    try std.testing.expect(allow.enable("warn"));
    try std.testing.expect(allow.enable("error"));

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console_allow = allow,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_console.id));
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
