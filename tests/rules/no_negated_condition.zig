const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-negated-condition for if else and ternary tests" {
    const source =
        \\if (!ready) {
        \\  wait();
        \\} else {
        \\  run();
        \\}
        \\const value = count !== expected ? left : right;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_negated_condition.id));
}

test "does not report no-negated-condition without plain else or with positive tests" {
    const source =
        \\if (!ready) {
        \\  wait();
        \\}
        \\if (count !== expected) {
        \\  left();
        \\} else if (fallback) {
        \\  right();
        \\}
        \\if (ready) {
        \\  run();
        \\} else {
        \\  wait();
        \\}
        \\const value = ready ? left : right;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_negated_condition.id));
}

test "can disable no-negated-condition" {
    const source =
        \\if (!ready) {
        \\  wait();
        \\} else {
        \\  run();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_negated_condition = false,
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_negated_condition.id));
}
