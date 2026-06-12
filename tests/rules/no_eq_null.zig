const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-eq-null for loose null comparisons" {
    const source =
        \\if (value == null) call(value);
        \\if (null != value) call(value);
        \\if ((value) == (null)) call(value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .eqeqeq = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_eq_null.id));
    try std.testing.expectEqualStrings("Use strict equality operators when comparing with null.", result.diagnostics[0].message);
}

test "does not report no-eq-null for strict null comparisons or non-null loose comparisons" {
    const source =
        \\if (value === null) call(value);
        \\if (value !== null) call(value);
        \\if (value == undefined) call(value);
        \\if (value == 0) call(value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .eqeqeq = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_eq_null.id));
}

test "can disable no-eq-null" {
    const source = "if (value == null) call(value);";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .eqeqeq = false,
        .no_eq_null = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_eq_null.id));
}
