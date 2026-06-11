const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports default-case for switch statements without default" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    runOne();
        \\    break;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.default_case.id));
}

test "does not report default-case when default exists or comment opts out" {
    const source =
        \\switch (first) {
        \\  case 1:
        \\    runOne();
        \\    break;
        \\  default:
        \\    runDefault();
        \\}
        \\switch (second) {
        \\  // no default
        \\  case 1:
        \\    runOne();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.default_case.id));
}

test "can disable default-case" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    runOne();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .default_case = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.default_case.id));
}
