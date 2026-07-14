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

test "supports configured spaced-comment markers" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\",{\"markers\":[\"/\",\"!\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("spaced-comment", config.value);
    options.no_inline_comments = false;
    options.no_tabs = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\/// <reference path="types.d.ts" />
        \\/*! license */
        \\//missing space
        \\/*missing space */
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.spaced_comment.id));
}

test "supports configured spaced-comment exceptions" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\",{\"exceptions\":[\"-\",\"+\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("spaced-comment", config.value);
    options.no_inline_comments = false;
    options.no_tabs = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\//----------------
        \\//++++
        \\//+ heading
        \\//missing space
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
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

test "autofixes missing spaces after comment markers" {
    const source =
        \\//line comment
        \\/*block comment */
        \\/**jsdoc comment */
        \\const value = 1; //inline comment
    ;
    const expected =
        \\// line comment
        \\/* block comment */
        \\/** jsdoc comment */
        \\const value = 1; // inline comment
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_inline_comments = false,
        .no_tabs = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.spaced_comment.id));
}

test "autofixes spaces and tabs disallowed after comment markers" {
    const source =
        "//   line comment\n" ++
        "/*\tblock comment */\n" ++
        "/**  jsdoc comment */";
    const expected =
        "//line comment\n" ++
        "/*block comment */\n" ++
        "/**jsdoc comment */";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .spaced_comment_style = .never,
        .no_inline_comments = false,
        .no_tabs = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.spaced_comment.id));
}

test "does not autofix a disallowed newline after a block comment marker" {
    const source =
        \\/*
        \\line comment */
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .spaced_comment_style = .never,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!result.fixed);
    try std.testing.expectEqualStrings(source, result.output);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result.result, lint.rules.spaced_comment.id));
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.spaced_comment.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
}
