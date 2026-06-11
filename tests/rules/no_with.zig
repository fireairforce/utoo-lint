const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "can disable no-with" {
    const source =
        \\with (point) {
        \\  x = 1;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", .{
        .no_with = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_with.id));
}

test "reports no-with for with statements" {
    const source =
        \\with (point) {
        \\  x = 1;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(helpers.hasRule(result, lint.rules.no_with.id));
}
