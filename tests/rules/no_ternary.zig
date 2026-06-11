const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-ternary for conditional expressions" {
    const source =
        \\const value = ready ? a : b;
        \\const nested = first ? second ? a : b : c;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_ternary.id));
}

test "does not report no-ternary for if statements" {
    const source =
        \\if (ready) {
        \\  use(a);
        \\} else {
        \\  use(b);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_ternary.id));
}

test "can disable no-ternary" {
    const source =
        \\const value = ready ? a : b;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_ternary = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_ternary.id));
}
