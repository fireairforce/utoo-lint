const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-new-native-nonconstructor for global Symbol and BigInt constructors" {
    const source =
        \\const symbol = new Symbol("value");
        \\const wrapped = new (Symbol)("value");
        \\const bigint = new BigInt(1);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_new_native_nonconstructor.id));
}

test "does not report no-new-native-nonconstructor for calls or shadowed names" {
    const source =
        \\const symbol = Symbol("value");
        \\const bigint = BigInt(1);
        \\function local(Symbol, BigInt) {
        \\  const localSymbol = new Symbol("value");
        \\  const localBigInt = new BigInt(1);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_new_native_nonconstructor.id));
}

test "can disable no-new-native-nonconstructor" {
    const source =
        \\const symbol = new Symbol("value");
        \\const bigint = new BigInt(1);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new_native_nonconstructor = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_new_native_nonconstructor.id));
}
