const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-empty-block-statements for empty blocks" {
    const source =
        \\if (ready) {}
        \\function empty() {}
        \\class C {
        \\  static {}
        \\  method() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_empty_block_statements.id));
}

test "does not report no-empty-block-statements for commented blocks" {
    const source =
        \\if (ready) { /* intentionally empty */ }
        \\function empty() {
        \\  // intentionally empty
        \\}
        \\class C {
        \\  static { /* intentionally empty */ }
        \\  method() { /* intentionally empty */ }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_empty_block_statements.id));
}

test "can disable no-empty-block-statements" {
    const source =
        \\if (ready) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_empty_block_statements.id));
}
