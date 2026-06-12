const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-loss-of-precision for imprecise number literals" {
    const source =
        \\const tooLarge = 9007199254740993;
        \\const separated = 9_007_199_254_740_993;
        \\const fractional = .1230000000000000000000000;
        \\const hex = 0X20000000000001;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_floating_decimal = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.typescript_eslint_no_loss_of_precision.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_loss_of_precision.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_loss_of_precision.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "does not report @typescript-eslint/no-loss-of-precision for safe literals or bigint" {
    const source =
        \\const small = 12345;
        \\const exponent = 123e34;
        \\const max = 9007199254740991;
        \\const bigint = 9007199254740993n;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_loss_of_precision.id));
}

test "can disable @typescript-eslint/no-loss-of-precision and fall back to core rule" {
    const source =
        \\const tooLarge = 9007199254740993;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_loss_of_precision = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_loss_of_precision.id));
    try std.testing.expect(helpers.hasRule(result, lint.rules.no_loss_of_precision.id));
}
