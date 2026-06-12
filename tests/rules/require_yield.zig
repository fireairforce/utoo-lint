const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports require-yield for generators without their own yield" {
    const source =
        \\function* empty() {}
        \\function* onlyNested() {
        \\  function* nested() {
        \\    yield value;
        \\  }
        \\}
        \\const obj = {
        \\  *emptyMethod() {}
        \\};
        \\class Example {
        \\  *emptyMethod() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_empty_block_statements = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.require_yield.id));
}

test "does not report require-yield for generators with yield or non-generators" {
    const source =
        \\function* values() {
        \\  yield value;
        \\}
        \\function* delegate() {
        \\  yield* values();
        \\}
        \\const obj = {
        \\  *method() {
        \\    if (ready) {
        \\      yield value;
        \\    }
        \\  }
        \\};
        \\function normal() {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.require_yield.id));
}

test "can disable require-yield" {
    const source =
        \\function* empty() {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .require_yield = false,
        .no_empty_function = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.require_yield.id));
}
