const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports spaced-comment for comments without spacing" {
    const source =
        \\//missing space
        \\/// <reference path="types.d.ts" />
        \\/*missing space */
        \\/**missing space */
        \\/*! license */
        \\const value = 1; //inline missing space
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_inline_comments = false,
        .no_tabs = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.spaced_comment.id));
}

test "does not report spaced-comment for spaced comments and jsdoc markers" {
    const source =
        \\// line comment
        \\// another line comment
        \\/* block comment */
        \\/**
        \\ * jsdoc
        \\ */
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
        \\/** jsdoc marker space is disallowed */
        \\//nospace
        \\/*nospace */
        \\/// common marker
        \\/**jsdoc */
        \\/*! license */
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

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.spaced_comment.id));
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
