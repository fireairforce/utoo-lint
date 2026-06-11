const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-nested-ternary for conditional expressions inside branches" {
    const source =
        \\const first = foo ? bar ? a : b : c;
        \\const second = foo ? a : bar ? b : c;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_ternary = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_nested_ternary.id));
}

test "does not report no-nested-ternary for simple conditional expressions" {
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

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_nested_ternary.id));
}

test "can disable no-nested-ternary" {
    const source =
        \\const value = foo ? bar ? a : b : c;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_nested_ternary = false,
        .no_ternary = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_nested_ternary.id));
}
