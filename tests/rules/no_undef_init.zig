const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-undef-init for var and let initializers" {
    const source =
        \\var first = undefined;
        \\let second = undefined;
        \\let third = (undefined);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_var = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_undef_init.id));
}

test "does not report no-undef-init for const or useful initializers" {
    const source =
        \\const first = undefined;
        \\let second;
        \\let third = void 0;
        \\let fourth = value;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_void = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_undef_init.id));
}

test "can disable no-undef-init" {
    const source =
        \\let value = undefined;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef_init = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_undef_init.id));
}
