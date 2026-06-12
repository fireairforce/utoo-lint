const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports one-var for combined variable declarations" {
    const source =
        \\let first = 1, second = 2;
        \\const third = 3, fourth = 4;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.one_var.id));
}

test "does not report one-var for separate declarations or for loop init" {
    const source =
        \\let first = 1;
        \\let second = 2;
        \\for (let i = 0, j = 10; i < j; i++) {
        \\  second += i;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_plusplus = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.one_var.id));
}

test "can disable one-var" {
    const source =
        \\let first = 1, second = 2;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .one_var = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.one_var.id));
}
