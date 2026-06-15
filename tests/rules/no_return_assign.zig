const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-return-assign for returned assignments" {
    const source =
        \\function update(value, next) {
        \\  return value = next;
        \\}
        \\const assign = (value, next) => value += next;
        \\function sequence(value, next) {
        \\  return other, value = next;
        \\}
        \\function parenthesizedSequence(value, next) {
        \\  return (other, value = next);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_return_assign.id));
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
        \\function callArgument(value, next) {
        \\  return use(value = next);
        \\}
        \\function binary(value, next) {
        \\  return other + (value = next);
        \\}
        \\function logical(value, next) {
        \\  return other && (value = next);
        \\}
        \\function conditional(value, next) {
        \\  return other ? (value = next) : fallback;
        \\}
        \\function unary(value, next) {
        \\  return !(value = next);
        \\}
        \\function sequence(value, next) {
        \\  return other, (value = next);
        \\}
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
        \\function callArgument(value, next) {
        \\  return use(value = next);
        \\}
        \\function binary(value, next) {
        \\  return other + (value = next);
        \\}
        \\function logical(value, next) {
        \\  return other && (value = next);
        \\}
        \\function conditional(value, next) {
        \\  return other ? (value = next) : fallback;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_return_assign_style = .always,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.no_return_assign.id));
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
