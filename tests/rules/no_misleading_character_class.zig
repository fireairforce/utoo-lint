const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-misleading-character-class for misleading regex character classes" {
    const source =
        \\/[👍]/;
        \\/[a\u0301]/;
        \\/[👨‍👩‍👧‍👦]/u;
        \\RegExp("[❤️]", "u");
        \\/[\uD83D\uDE00]/u;
        \\/[👶🏻]/u;
        \\/[🇯🇵]/u;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.no_misleading_character_class.id));
}

test "does not report no-misleading-character-class for valid character classes" {
    const source =
        \\/[👍]/u;
        \\/[abc]/;
        \\/\\u{1F600}/;
        \\/[\u0301]/u;
        \\/[\d\u0301]/u;
        \\RegExp("[abc]", "u");
        \\function local(RegExp) {
        \\  RegExp("[👍]");
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_misleading_character_class.id));
}

test "can disable no-misleading-character-class" {
    const source =
        \\/[👍]/;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_misleading_character_class = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_misleading_character_class.id));
}
