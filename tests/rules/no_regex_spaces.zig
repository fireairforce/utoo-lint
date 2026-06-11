const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-regex-spaces for consecutive regex pattern spaces" {
    const source =
        \\const first = /foo  bar/;
        \\const second = /foo   bar/;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_regex_spaces.id));
}

test "does not report no-regex-spaces for escaped or character class spaces" {
    const source =
        \\const first = /foo bar/;
        \\const second = /foo\ \ bar/;
        \\const third = /[  ]/;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_regex_spaces.id));
}

test "can disable no-regex-spaces" {
    const source =
        \\const first = /foo  bar/;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_regex_spaces = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_regex_spaces.id));
}
