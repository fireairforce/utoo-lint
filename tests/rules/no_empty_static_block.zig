const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-empty-static-block for empty static blocks" {
    const source =
        \\class First {
        \\  static {}
        \\}
        \\class Second {
        \\  static {
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_empty_static_block.id));
}

test "does not report no-empty-static-block for non-empty or commented static blocks" {
    const source =
        \\class First {
        \\  static { setup(); }
        \\}
        \\class Second {
        \\  static { /* intentionally empty */ }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_empty_static_block.id));
}

test "can disable no-empty-static-block" {
    const source =
        \\class First {
        \\  static {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_static_block = false,
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_empty_static_block.id));
}
