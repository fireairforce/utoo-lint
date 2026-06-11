const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-unneeded-ternary for boolean literal branches" {
    const source =
        \\const first = enabled ? true : false;
        \\const second = enabled ? false : true;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_ternary = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_unneeded_ternary.id));
}

test "does not report no-unneeded-ternary for non-boolean branches or default assignments" {
    const source =
        \\const first = enabled ? value : fallback;
        \\const second = enabled ? enabled : fallback;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_ternary = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unneeded_ternary.id));
}

test "can disable no-unneeded-ternary" {
    const source =
        \\const value = enabled ? true : false;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unneeded_ternary = false,
        .no_ternary = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unneeded_ternary.id));
}
