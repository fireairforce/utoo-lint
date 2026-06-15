const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-return-assign for returned assignments" {
    const source =
        \\function update(value, next) {
        \\  return value = next;
        \\}
        \\const assign = (value, next) => value += next;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_return_assign.id));
}

test "does not report no-return-assign for comparisons or parenthesized assignments" {
    const source =
        \\function compare(value, next) {
        \\  return value === next;
        \\}
        \\function update(value, next) {
        \\  return (value = next);
        \\}
        \\const assign = (value, next) => (value += next);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_return_assign.id));
}

test "reports parenthesized returned assignments in always mode" {
    const source =
        \\function update(value, next) {
        \\  return (value = next);
        \\}
        \\const assign = (value, next) => (value += next);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_return_assign_style = .always,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_return_assign.id));
}

test "can disable no-return-assign" {
    const source =
        \\function update(value, next) {
        \\  return value = next;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_return_assign = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_return_assign.id));
}
