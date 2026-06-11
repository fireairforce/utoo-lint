const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-empty-pattern for empty destructuring patterns" {
    const source =
        \\const {} = object;
        \\const [] = list;
        \\function first({}) {}
        \\function second([]) {}
        \\const { value: {} } = object;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_empty_pattern.id));
}

test "does not report no-empty-pattern for non-empty destructuring patterns" {
    const source =
        \\const { value } = object;
        \\const [value] = list;
        \\const [...items] = list;
        \\const { ...rest } = object;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_empty_pattern.id));
}

test "can disable no-empty-pattern" {
    const source =
        \\const {} = object;
        \\const [] = list;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_pattern = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_empty_pattern.id));
}
