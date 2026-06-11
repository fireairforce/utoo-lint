const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-async-promise-executor for async promise executors" {
    const source =
        \\new Promise(async (resolve) => resolve());
        \\new Promise(async function (resolve) {
        \\  resolve();
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_async_promise_executor.id));
}

test "does not report no-async-promise-executor for non-async executors or shadowed Promise" {
    const source =
        \\new Promise((resolve) => resolve());
        \\function local(Promise) {
        \\  new Promise(async (resolve) => resolve());
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_async_promise_executor.id));
}

test "can disable no-async-promise-executor" {
    const source =
        \\new Promise(async (resolve) => resolve());
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_async_promise_executor = false,
        .no_new = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_async_promise_executor.id));
}
