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
