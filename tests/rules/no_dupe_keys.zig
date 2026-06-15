const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-dupe-keys for duplicate object literal keys" {
    const source =
        \\const object = {
        \\  alpha: 1,
        \\  alpha: 2,
        \\  "beta": 1,
        \\  beta: 2,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_dupe_keys.id));
}

test "does not report no-dupe-keys for computed keys or getter setter pairs" {
    const source =
        \\const object = {
        \\  [alpha]: 1,
        \\  [alpha]: 2,
        \\  get value() { return 1; },
        \\  set value(next) {},
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_dupe_keys.id));
}

test "reports no-dupe-keys for equivalent numeric object keys" {
    const source =
        \\const object = {
        \\  0x1: "hex",
        \\  1: "decimal",
        \\  1_0: "separated",
        \\  10: "ten",
        \\  "2": "string",
        \\  2: "number",
        \\  1.5: "fraction",
        \\  1.50: "sameFraction",
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_dupe_keys.id));
}

test "can disable no-dupe-keys" {
    const source =
        \\const object = { alpha: 1, alpha: 2 };
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_dupe_keys = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_dupe_keys.id));
}
