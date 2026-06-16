const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-compare-neg-zero for comparisons against negative zero" {
    const source =
        \\x === -0;
        \\-0 == x;
        \\x < -0;
        \\-0 >= x;
        \\x === -(0);
        \\(-0) === x;
        \\x === -0.0;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.no_compare_neg_zero.id));
}

test "does not report no-compare-neg-zero for non-comparisons" {
    const source =
        \\x === 0;
        \\x === -1;
        \\x === +0;
        \\Object.is(x, -0);
        \\x || -0;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_compare_neg_zero.id));
}

test "can disable no-compare-neg-zero" {
    const source =
        \\x === -0;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_compare_neg_zero = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_compare_neg_zero.id));
}
