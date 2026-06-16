const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-sparse-arrays for array holes" {
    const source =
        \\const first = [1,, 2];
        \\const second = [,];
        \\const third = [,,];
        \\const fourth = [,,...items];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.no_sparse_arrays.id));
}

test "does not report no-sparse-arrays for explicit values" {
    const source =
        \\const first = [1, undefined, 2];
        \\const second = [...items];
        \\const third = [];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_sparse_arrays.id));
}

test "can disable no-sparse-arrays" {
    const source =
        \\const first = [1,, 2];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_sparse_arrays = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_sparse_arrays.id));
}
