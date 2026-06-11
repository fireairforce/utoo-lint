const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "can disable no-for-in" {
    const source =
        \\for (const key in object) {
        \\  console.log(key);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_for_in = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_for_in.id));
}

test "reports no-for-in for for-in statements" {
    const source =
        \\for (const key in object) {
        \\  use(key);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(helpers.hasRule(result, lint.rules.no_for_in.id));
}
