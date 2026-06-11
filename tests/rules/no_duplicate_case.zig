const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-duplicate-case for repeated switch case labels" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    break;
        \\  case 2:
        \\    break;
        \\  case 1:
        \\    break;
        \\  case name:
        \\    break;
        \\  case name:
        \\    break;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_duplicate_case.id));
}

test "does not report no-duplicate-case for distinct labels or default clauses" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    break;
        \\  case "1":
        \\    break;
        \\  default:
        \\    break;
        \\}
        \\switch (other) {
        \\  case 1:
        \\    break;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_duplicate_case.id));
}

test "can disable no-duplicate-case" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    break;
        \\  case 1:
        \\    break;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_duplicate_case = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_duplicate_case.id));
}
