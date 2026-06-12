const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/ban-tslint-comment enable and disable directives" {
    const source =
        \\// tslint:disable
        \\// tslint:disable-line:no-any
        \\// tslint:disable-next-line no-console
        \\/* tslint:enable */
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_inline_comments = false,
        .no_unused_vars = false,
        .spaced_comment = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.typescript_eslint_ban_tslint_comment.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_ban_tslint_comment.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "does not report non-tslint comments" {
    const source =
        \\// tslint:disablement is just text
        \\// eslint-disable-next-line no-console
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_inline_comments = false,
        .no_unused_vars = false,
        .spaced_comment = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_ban_tslint_comment.id));
}

test "can disable @typescript-eslint/ban-tslint-comment" {
    const source =
        \\// tslint:disable
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_inline_comments = false,
        .no_unused_vars = false,
        .spaced_comment = false,
        .typescript_eslint_ban_tslint_comment = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_ban_tslint_comment.id));
}
