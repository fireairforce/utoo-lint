const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-empty-function for empty function bodies" {
    const source =
        \\function empty() {}
        \\const arrow = () => {};
        \\class Example {
        \\  method() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_empty_function = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_empty_function.id));
}

test "does not report no-empty-function for non-empty or commented bodies" {
    const source =
        \\function nonempty() {
        \\  return 1;
        \\}
        \\const documented = () => {
        \\  // intentionally empty
        \\};
        \\class Example {
        \\  method() { /* noop */ }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_empty_function = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_empty_function.id));
}

test "can disable no-empty-function" {
    const source =
        \\function empty() {}
        \\const arrow = () => {};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_empty_function = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_empty_function.id));
}
