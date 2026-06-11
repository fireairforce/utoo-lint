const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-floating-decimal for leading or trailing decimal points" {
    const source =
        \\const leading = .5;
        \\const trailing = 2.;
        \\const negative = -.7;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_floating_decimal.id));
}

test "does not report no-floating-decimal for complete decimal literals" {
    const source =
        \\const whole = 2;
        \\const decimal = 2.0;
        \\const zero = 0.5;
        \\const exponent = 1e3;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_floating_decimal.id));
}

test "can disable no-floating-decimal" {
    const source =
        \\const leading = .5;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_floating_decimal = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_floating_decimal.id));
}
