const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-bitwise for bitwise binary and unary operators" {
    const source =
        \\const a = left | right;
        \\const b = left ^ right;
        \\const c = left & right;
        \\const d = left << right;
        \\const e = left >> right;
        \\const f = left >>> right;
        \\const g = ~value;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.no_bitwise.id));
}

test "reports no-bitwise for bitwise assignment operators" {
    const source =
        \\value |= mask;
        \\value ^= mask;
        \\value &= mask;
        \\value <<= bits;
        \\value >>= bits;
        \\value >>>= bits;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.no_bitwise.id));
}

test "does not report no-bitwise for logical or arithmetic operators" {
    const source =
        \\const a = left || right;
        \\const b = left && right;
        \\const c = left + right;
        \\const d = !value;
        \\value += amount;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_bitwise.id));
}

test "can disable no-bitwise" {
    const source =
        \\const value = left | right;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_bitwise = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_bitwise.id));
}
