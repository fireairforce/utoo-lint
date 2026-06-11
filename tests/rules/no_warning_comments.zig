const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-warning-comments for default warning terms at comment start" {
    const source =
        \\// TODO: handle this case
        \\/* fixme rewrite this */
        \\// xxx
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_warning_comments.id));
}

test "does not report no-warning-comments away from start or as partial words" {
    const source =
        \\// this TODO is not at the start
        \\// todoing is not the whole word
        \\/* * TODO decoration is not ignored by default */
        \\const value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_warning_comments.id));
}

test "can disable no-warning-comments" {
    const source =
        \\// TODO: handle this case
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_warning_comments = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_warning_comments.id));
}
