const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-confusing-non-null-assertion for confusing equality and assignment" {
    const source =
        \\a! == b;
        \\a! === b;
        \\a! = b;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .eqeqeq = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.typescript_eslint_no_confusing_non_null_assertion.id));
}

test "does not report @typescript-eslint/no-confusing-non-null-assertion for parenthesized assertions or inequality" {
    const source =
        \\(a!) == b;
        \\a! != b;
        \\a! !== b;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .eqeqeq = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_confusing_non_null_assertion.id));
}

test "can disable @typescript-eslint/no-confusing-non-null-assertion" {
    const source =
        \\a! == b;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .eqeqeq = false,
        .no_undef = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_confusing_non_null_assertion = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_confusing_non_null_assertion.id));
}
