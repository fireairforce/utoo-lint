const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports require-await for async functions without await" {
    const source =
        \\async function first() {
        \\  return value;
        \\}
        \\const second = async () => value;
        \\const third = async function () {
        \\  return value;
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.require_await.id));
    try std.testing.expectEqualStrings("Async function has no await expression.", result.diagnostics[0].message);
}

test "allows async functions with await and ignores nested awaits" {
    const source =
        \\async function withAwait() {
        \\  await value;
        \\}
        \\const expressionBody = async () => await value;
        \\async function outer() {
        \\  async function inner() {
        \\    await value;
        \\  }
        \\  return inner;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.require_await.id));
}

test "allows non-async functions and async generators" {
    const source =
        \\function regular() {
        \\  return value;
        \\}
        \\async function* generator() {
        \\  yield value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.require_await.id));
}

test "can disable require-await" {
    const source = "async function first() {}\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .require_await = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.require_await.id));
}
