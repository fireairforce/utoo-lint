const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports use-isnan for equality comparisons with NaN" {
    const source =
        \\if (value == NaN) { use(value); }
        \\if (NaN !== value) { use(value); }
        \\if ((value) != (NaN)) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.use_isnan.id));
}

test "does not report use-isnan for non-equality comparisons or Number.isNaN" {
    const source =
        \\if (value > NaN) { use(value); }
        \\if (Number.isNaN(value)) { use(value); }
        \\if (isNaN(value)) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.use_isnan.id));
}

test "can disable use-isnan" {
    const source =
        \\if (value === NaN) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .use_isnan = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.use_isnan.id));
}
