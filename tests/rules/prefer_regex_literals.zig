const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports prefer-regex-literals for static RegExp constructors" {
    const source =
        \\RegExp("abc");
        \\new RegExp("abc");
        \\new RegExp("abc", "u");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_new = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.prefer_regex_literals.id));
    try std.testing.expectEqualStrings(
        "Use a regular expression literal instead of the RegExp constructor.",
        result.diagnostics[0].message,
    );
}

test "does not report prefer-regex-literals for dynamic patterns or shadowed RegExp" {
    const source =
        \\RegExp(pattern);
        \\RegExp("abc", flags);
        \\RegExp("abc", "u", "extra");
        \\const RegExp = function () {};
        \\RegExp("abc");
        \\new RegExp("abc");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_new = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_regex_literals.id));
}

test "can disable prefer-regex-literals" {
    const source =
        \\RegExp("abc");
        \\new RegExp("abc");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_new = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .prefer_regex_literals = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_regex_literals.id));
}
