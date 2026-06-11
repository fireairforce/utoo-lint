const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-lonely-if for if as only else block statement" {
    const source =
        \\if (first) {
        \\  runFirst();
        \\} else {
        \\  if (second) {
        \\    runSecond();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_else_return = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_lonely_if.id));
}

test "does not report no-lonely-if when else block has multiple statements" {
    const source =
        \\if (first) {
        \\  runFirst();
        \\} else {
        \\  prepare();
        \\  if (second) {
        \\    runSecond();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_lonely_if.id));
}

test "can disable no-lonely-if" {
    const source =
        \\if (first) {
        \\  runFirst();
        \\} else {
        \\  if (second) {
        \\    runSecond();
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_lonely_if = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_lonely_if.id));
}
