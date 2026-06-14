const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports capitalized-comments for comments starting with lowercase words" {
    const source =
        \\// lowercase line comment
        \\/* lowercase block comment */
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .spaced_comment = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.capitalized_comments.id));
    try std.testing.expectEqualStrings("Comments should start with an uppercase character.", result.diagnostics[0].message);
}

test "allows uppercase, numeric, symbolic, directives, urls, and empty comments" {
    const source =
        \\// Uppercase line comment
        \\/* Uppercase block comment */
        \\// 123 numeric prefix
        \\// _symbolic prefix
        \\// eslint-disable-next-line no-alert
        \\/* global window */
        \\// https://example.com/path
        \\//
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .spaced_comment = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.capitalized_comments.id));
}

test "reports capitalized-comments for uppercase starts in never mode" {
    const source =
        \\// Uppercase line comment
        \\/* Lowercase block comment */
        \\// lowercase line comment
        \\/* lowercase block comment */
        \\// eslint-disable-next-line no-alert
        \\// https://example.com/path
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments_mode = .never,
        .no_unused_vars = false,
        .spaced_comment = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.capitalized_comments.id));
    try std.testing.expectEqualStrings("Comments should not start with an uppercase character.", result.diagnostics[0].message);
}

test "can disable capitalized-comments" {
    const source =
        \\// lowercase line comment
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.capitalized_comments.id));
}
