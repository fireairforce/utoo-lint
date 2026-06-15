const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports spaced-comment for comments without spacing" {
    const source =
        \\//missing space
        \\/*missing space */
        \\const value = 1; //inline missing space
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_inline_comments = false,
        .no_tabs = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.spaced_comment.id));
}

test "does not report spaced-comment for spaced comments and common markers" {
    const source =
        \\// line comment
        \\// another line comment
        \\///
        \\/// <reference path="types.d.ts" />
        \\/* block comment */
        \\/**
        \\ * jsdoc
        \\ */
        \\/*! license */
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_inline_comments = false,
        .no_tabs = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.spaced_comment.id));
}

test "reports spaced-comment for spaced comments in never mode" {
    const source =
        \\// space is disallowed
        \\/* block space is disallowed */
        \\//nospace
        \\/*nospace */
        \\/// common marker
        \\/** jsdoc */
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .spaced_comment_style = .never,
        .no_inline_comments = false,
        .no_tabs = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.spaced_comment.id));
}

test "can disable spaced-comment" {
    const source =
        \\//missing space
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .spaced_comment = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.spaced_comment.id));
}
