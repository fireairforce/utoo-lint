const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-global-is-nan for global isNaN calls" {
    const source =
        \\isNaN({});
        \\(isNaN)({});
        \\globalThis.isNaN({});
        \\globalThis["isNaN"]({});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_global_is_nan.id));
}

test "does not report no-global-is-nan for shadowed isNaN" {
    const source =
        \\function local(isNaN) {
        \\  isNaN({});
        \\}
        \\Number.isNaN({});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_global_is_nan.id));
}

test "can disable no-global-is-nan" {
    const source =
        \\isNaN({});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_global_is_nan = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_global_is_nan.id));
}
