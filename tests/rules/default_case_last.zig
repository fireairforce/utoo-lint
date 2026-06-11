const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports default-case-last when default is before another case" {
    const source =
        \\switch (value) {
        \\  default:
        \\    runDefault();
        \\    break;
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

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.default_case_last.id));
}

test "does not report default-case-last when default is last or absent" {
    const source =
        \\switch (first) {
        \\  case 1:
        \\    runOne();
        \\    break;
        \\  default:
        \\    runDefault();
        \\}
        \\switch (second) {
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

    try std.testing.expect(!helpers.hasRule(result, lint.rules.default_case_last.id));
}

test "can disable default-case-last" {
    const source =
        \\switch (value) {
        \\  default:
        \\    runDefault();
        \\  case 1:
        \\    runOne();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .default_case = false,
        .default_case_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.default_case_last.id));
}
