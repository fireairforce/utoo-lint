const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-nonoctal-decimal-escape for decimal escape sequences" {
    const source =
        \\const first = "\8";
        \\const second = '\9';
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_nonoctal_decimal_escape.id));
}

test "does not report no-nonoctal-decimal-escape for ordinary strings" {
    const source =
        \\const first = "8";
        \\const second = "9";
        \\const third = "\\8";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_nonoctal_decimal_escape.id));
}

test "can disable no-nonoctal-decimal-escape" {
    const source =
        \\const first = "\8";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_nonoctal_decimal_escape = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_nonoctal_decimal_escape.id));
}
