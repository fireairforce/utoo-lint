const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-return-await for async return await outside try blocks" {
    const source =
        \\async function first() {
        \\  return await value;
        \\}
        \\const second = async () => {
        \\  return await value;
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_return_await.id));
}

test "does not report no-return-await outside async functions or inside try blocks" {
    const source =
        \\function normal() {
        \\  return value;
        \\}
        \\async function guarded() {
        \\  try {
        \\    return await value;
        \\  } catch (error) {
        \\    return value;
        \\  }
        \\}
        \\async function nested() {
        \\  function inner() {
        \\    return value;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_return_await.id));
}

test "can disable no-return-await" {
    const source =
        \\async function first() {
        \\  return await value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_return_await = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_return_await.id));
}
