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

test "autofixes leading and trailing decimal points" {
    const source =
        \\const leading = .5;
        \\const trailing = 2.;
        \\const negative = -.7;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\const leading = 0.5;
        \\const trailing = 2.0;
        \\const negative = -0.7;
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_floating_decimal.id));
}

test "autofix separates leading decimals from adjacent keywords" {
    const source =
        \\typeof.2;
        \\for (item of.3);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .curly = false,
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\typeof 0.2;
        \\for (item of 0.3);
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_floating_decimal.id));
}
