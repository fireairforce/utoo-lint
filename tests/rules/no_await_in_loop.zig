const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-await-in-loop for await expressions inside loop bodies" {
    const source =
        \\async function run(items) {
        \\  for (const item of items) {
        \\    await work(item);
        \\  }
        \\  while (ready) {
        \\    await next();
        \\  }
        \\  do {
        \\    await finish();
        \\  } while (again);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_await_in_loop.id));
}

test "reports no-await-in-loop for await in for test and update" {
    const source =
        \\async function run() {
        \\  for (; await ready(); step()) {}
        \\  for (; ready; await step()) {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_await_in_loop.id));
}

test "does not report no-await-in-loop outside loops or across nested functions" {
    const source =
        \\async function run(items) {
        \\  await setup();
        \\  for (await setup(); ready; step()) {
        \\    use();
        \\  }
        \\  for (const item of items) {
        \\    async function nested() {
        \\      await work(item);
        \\    }
        \\    const callback = async () => {
        \\      await other(item);
        \\    };
        \\  }
        \\  for await (const item of items) {
        \\    use(item);
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

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_await_in_loop.id));
}

test "reports no-await-in-loop for for-init await inside an outer loop" {
    const source =
        \\async function run() {
        \\  while (ready) {
        \\    for (await setup(); active; step()) {}
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

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_await_in_loop.id));
}

test "can disable no-await-in-loop" {
    const source =
        \\async function run(items) {
        \\  for (const item of items) {
        \\    await work(item);
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_await_in_loop = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_await_in_loop.id));
}
