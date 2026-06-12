const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-multi-assign for chained assignments" {
    const source =
        \\let a, b, c, d;
        \\a = b = c;
        \\a = (b = c);
        \\a = b = c = d;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_multi_assign.id));
}

test "does not report no-multi-assign for single assignments" {
    const source =
        \\let a, b, c;
        \\a = b;
        \\a += b;
        \\a = condition ? b = c : c;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), helpers.countRule(result, lint.rules.no_multi_assign.id));
}

test "can disable no-multi-assign" {
    const source =
        \\let a, b, c;
        \\a = b = c;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_multi_assign = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_multi_assign.id));
}
