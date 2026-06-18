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

test "ignores only inline comments when ignoreInlineComments is enabled" {
    const source =
        \\const first = call(/* lowercase inline block */ value);
        \\const second = value; // lowercase trailing line comment
        \\/* lowercase standalone block */
        \\const third = 1;
    ;

    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .spaced_comment = false,
        .parser_semantic_errors = false,
    });
    defer default_result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(default_result, lint.rules.capitalized_comments.id));

    var ignored_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments_ignore_inline_comments = .yes,
        .no_unused_vars = false,
        .spaced_comment = false,
        .parser_semantic_errors = false,
    });
    defer ignored_result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(ignored_result, lint.rules.capitalized_comments.id));
}

test "ignores consecutive comments when ignoreConsecutiveComments is enabled" {
    const source =
        \\// First comment starts a group
        \\// second consecutive line comment
        \\
        \\/* third consecutive block comment */
        \\const value = 1;
        \\// fourth comment starts a new group after code
    ;

    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .spaced_comment = false,
        .parser_semantic_errors = false,
    });
    defer default_result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(default_result, lint.rules.capitalized_comments.id));

    var ignored_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments_ignore_consecutive_comments = .yes,
        .no_unused_vars = false,
        .spaced_comment = false,
        .parser_semantic_errors = false,
    });
    defer ignored_result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(ignored_result, lint.rules.capitalized_comments.id));
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
