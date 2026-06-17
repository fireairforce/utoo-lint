const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/ban-ts-comment directives without descriptions" {
    const source =
        \\// @ts-expect-error
        \\// @ts-ignore
        \\/* @ts-nocheck */
        \\/* @ts-check */
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_inline_comments = false,
        .no_unused_vars = false,
        .spaced_comment = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.typescript_eslint_ban_ts_comment.id));
}

test "allows @typescript-eslint/ban-ts-comment directives with descriptions" {
    const source =
        \\// @ts-expect-error: legacy API mismatch
        \\// @ts-ignore because generated types lag runtime
        \\/* @ts-nocheck: vendored file */
        \\/* @ts-check enable project-local JS checking */
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_inline_comments = false,
        .no_unused_vars = false,
        .spaced_comment = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_ban_ts_comment.id));
}

test "uses configured @typescript-eslint/ban-ts-comment directive modes" {
    const source =
        \\// @ts-expect-error
        \\// @ts-ignore: described ignore
        \\/* @ts-nocheck */
        \\/* @ts-check */
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_inline_comments = false,
        .no_unused_vars = false,
        .spaced_comment = false,
        .typescript_eslint_ban_ts_comment_ts_expect_error = .allow,
        .typescript_eslint_ban_ts_comment_ts_ignore = .ban,
        .typescript_eslint_ban_ts_comment_ts_nocheck = .allow_with_description,
        .typescript_eslint_ban_ts_comment_ts_check = .allow,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_ban_ts_comment.id));
}

test "uses configured @typescript-eslint/ban-ts-comment minimumDescriptionLength" {
    const source =
        \\// @ts-expect-error: abc
        \\// @ts-ignore: abcdef
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_inline_comments = false,
        .no_unused_vars = false,
        .spaced_comment = false,
        .typescript_eslint_ban_ts_comment_minimum_description_length = 6,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_ban_ts_comment.id));
}

test "supports configured @typescript-eslint/ban-ts-comment options" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        \\["error", {"ts-expect-error": false, "ts-ignore": true, "ts-nocheck": "allow-with-description", "ts-check": false, "minimumDescriptionLength": 6}]
    ,
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("@typescript-eslint/ban-ts-comment", config.value);

    const Mode = @TypeOf((lint.Options{}).typescript_eslint_ban_ts_comment_ts_expect_error);
    try std.testing.expect(options.typescript_eslint_ban_ts_comment);
    try std.testing.expectEqual(Mode.allow, options.typescript_eslint_ban_ts_comment_ts_expect_error);
    try std.testing.expectEqual(Mode.ban, options.typescript_eslint_ban_ts_comment_ts_ignore);
    try std.testing.expectEqual(Mode.allow_with_description, options.typescript_eslint_ban_ts_comment_ts_nocheck);
    try std.testing.expectEqual(Mode.allow, options.typescript_eslint_ban_ts_comment_ts_check);
    try std.testing.expectEqual(@as(usize, 6), options.typescript_eslint_ban_ts_comment_minimum_description_length);
}

test "can disable @typescript-eslint/ban-ts-comment" {
    const source =
        \\// @ts-ignore
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_inline_comments = false,
        .no_unused_vars = false,
        .spaced_comment = false,
        .typescript_eslint_ban_ts_comment = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_ban_ts_comment.id));
}
