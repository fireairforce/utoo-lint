const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports radix for parseInt calls without radix" {
    const source =
        \\parseInt();
        \\parseInt(value);
        \\Number.parseInt(value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.radix.id));
}

test "reports radix for invalid literal or undefined radix" {
    const source =
        \\parseInt(value, 1);
        \\parseInt(value, 37);
        \\parseInt(value, "10");
        \\parseInt(value, undefined);
        \\parseInt(value, -10);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.radix.id));
}

test "does not report radix for valid radix arguments or shadowed globals" {
    const source =
        \\parseInt(value, 10);
        \\parseInt(value, 16);
        \\parseInt(value, radix);
        \\Number.parseInt(value, 10);
        \\function shadowed(parseInt, Number) {
        \\  parseInt(value);
        \\  Number.parseInt(value);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_const_assign = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.radix.id));
}

test "can disable radix" {
    const source =
        \\parseInt(value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .radix = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.radix.id));
}
