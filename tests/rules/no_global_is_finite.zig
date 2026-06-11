const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-global-is-finite for global isFinite calls" {
    const source =
        \\isFinite({});
        \\(isFinite)({});
        \\globalThis.isFinite({});
        \\globalThis["isFinite"]({});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_global_is_finite.id));
}

test "does not report no-global-is-finite for shadowed isFinite" {
    const source =
        \\function local(isFinite) {
        \\  isFinite({});
        \\}
        \\Number.isFinite({});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_global_is_finite.id));
}

test "can disable no-global-is-finite" {
    const source =
        \\isFinite({});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_global_is_finite = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_global_is_finite.id));
}
