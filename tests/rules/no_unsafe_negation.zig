const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-unsafe-negation before in and instanceof" {
    const source =
        \\!value in object;
        \\!value instanceof Constructor;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_unsafe_negation.id));
}

test "does not report no-unsafe-negation for other unary expressions" {
    const source =
        \\-value in object;
        \\~value in object;
        \\typeof value in object;
        \\void value in object;
        \\value instanceof Constructor;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_void = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unsafe_negation.id));
}

test "can disable no-unsafe-negation" {
    const source =
        \\!value in object;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unsafe_negation = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unsafe_negation.id));
}
