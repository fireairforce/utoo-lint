const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-regex-spaces for consecutive regex pattern spaces" {
    const source =
        \\const first = /foo  bar/;
        \\const second = /foo   bar/;
        \\const third = new RegExp("foo  bar");
        \\const fourth = RegExp("foo   bar", "g");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .prefer_regex_literals = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_regex_spaces.id));
}

test "does not report no-regex-spaces for escaped, character class, or dynamic constructor spaces" {
    const source =
        \\const first = /foo bar/;
        \\const second = /foo\ \ bar/;
        \\const third = /[  ]/;
        \\const fourth = new RegExp(`foo  bar`);
        \\const fifth = new RegExp(`foo ${value}  bar`);
        \\const sixth = new RegExp(pattern);
        \\const seventh = new globalThis.RegExp("foo  bar");
        \\function local(RegExp) {
        \\  const eighth = new RegExp("foo  bar");
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .prefer_regex_literals = false,
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
