const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-loss-of-precision for decimal literals with lost digits" {
    const source =
        \\const tooLarge = 9007199254740993;
        \\const manyDigits = 5123000000000000000000000000001;
        \\const decimal = 1230000000000000000000000.0;
        \\const fractional = .1230000000000000000000000;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_floating_decimal = false,
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_loss_of_precision = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_loss_of_precision.id));
}

test "reports no-loss-of-precision for non-decimal literals with lost bits" {
    const source =
        \\const hex = 0X20000000000001;
        \\const separated = 0X2_000000000_0001;
        \\const binary = 0b100000000000000000000000000000000000000000000000000001;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_loss_of_precision = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_loss_of_precision.id));
}

test "does not report no-loss-of-precision for safe or documented literals" {
    const source =
        \\const small = 12345;
        \\const decimal = 123.456;
        \\const exponent = 123e34;
        \\const trailingZeros = 12300000000000000000000000;
        \\const hex = 0x1FFFFFFFFFFFFF;
        \\const powerOfTwo = 0x20000000000000;
        \\const max = 9007199254740991;
        \\const separated = 9007_1992547409_91;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_loss_of_precision = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_loss_of_precision.id));
}

test "can disable no-loss-of-precision" {
    const source =
        \\const tooLarge = 9007199254740993;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_loss_of_precision = false,
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_loss_of_precision = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_loss_of_precision.id));
}
