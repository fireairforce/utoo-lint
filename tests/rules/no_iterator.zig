const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-iterator for iterator member access" {
    const source =
        \\foo.__iterator__ = bar;
        \\foo["__iterator__"] = bar;
        \\const iterator = foo.__iterator__;
        \\const iterator2 = foo["__iterator__"];
        \\foo[`__iterator__`] = bar;
        \\const iterator3 = foo[`__iterator__`];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.no_iterator.id));
}

test "does not report no-iterator for object literal properties or other members" {
    const source =
        \\const value = {
        \\  __iterator__: bar,
        \\  other: foo.__iter__,
        \\};
        \\foo[iterator] = bar;
        \\foo[`__${name}__`] = bar;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_iterator.id));
}

test "can disable no-iterator" {
    const source =
        \\const iterator = foo.__iterator__;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_iterator = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_iterator.id));
}
