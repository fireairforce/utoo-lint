const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-promise-executor-return for returned values" {
    const source =
        \\new Promise((resolve) => resolve());
        \\new Promise(function (resolve) {
        \\  if (ready) {
        \\    return resolve();
        \\  }
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_promise_executor_return.id));
}

test "does not report no-promise-executor-return for bare returns nested functions or shadowed Promise" {
    const source =
        \\new Promise(function (resolve) {
        \\  if (ready) return;
        \\  function nested() {
        \\    return resolve();
        \\  }
        \\});
        \\function local(Promise) {
        \\  new Promise((resolve) => resolve());
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_promise_executor_return.id));
}

test "can disable no-promise-executor-return" {
    const source =
        \\new Promise((resolve) => resolve());
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_promise_executor_return = false,
        .no_new = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_promise_executor_return.id));
}
