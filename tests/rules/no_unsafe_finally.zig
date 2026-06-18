const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-unsafe-finally for control flow in finally blocks" {
    const source =
        \\function one() {
        \\  try { use(); } finally { return 1; }
        \\}
        \\function two() {
        \\  try { use(); } finally { if (ready) { throw error; } }
        \\}
        \\function three() {
        \\  while (ready) {
        \\    try { use(); } finally { break; }
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_unsafe_finally.id));
}

test "does not report no-unsafe-finally for nested function control flow" {
    const source =
        \\function outer() {
        \\  try { use(); } finally {
        \\    function inner() {
        \\      return 1;
        \\    }
        \\    class Local {
        \\      method() {
        \\        return 2;
        \\      }
        \\    }
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unsafe_finally.id));
}

test "does not report no-unsafe-finally for local loop switch or label exits" {
    const source =
        \\function outer() {
        \\  try { use(); } finally {
        \\    while (ready) { break; }
        \\    for (;;) { continue; }
        \\    switch (value) { case 1: break; }
        \\    local: { break local; }
        \\    loop: while (ready) { continue loop; }
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unsafe_finally.id));
}

test "reports no-unsafe-finally for labeled exits leaving finally blocks" {
    const source =
        \\function outer() {
        \\  outerLoop: while (ready) {
        \\    try { use(); } finally { break outerLoop; }
        \\  }
        \\}
        \\function second() {
        \\  outerLoop: while (ready) {
        \\    try { use(); } finally { continue outerLoop; }
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_unsafe_finally.id));
}

test "reports no-unsafe-finally once for nested finally blocks" {
    const source =
        \\function outer() {
        \\  try { use(); } finally {
        \\    try { use(); } finally { return 1; }
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_unsafe_finally.id));
}

test "can disable no-unsafe-finally" {
    const source =
        \\function f() {
        \\  try { use(); } finally { return 1; }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unsafe_finally = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unsafe_finally.id));
}
