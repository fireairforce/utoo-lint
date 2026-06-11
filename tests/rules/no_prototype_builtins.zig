const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-prototype-builtins for direct object prototype method calls" {
    const source =
        \\foo.hasOwnProperty("bar");
        \\foo.isPrototypeOf(bar);
        \\foo.propertyIsEnumerable("bar");
        \\foo["hasOwnProperty"]("bar");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_prototype_builtins.id));
}

test "does not report no-prototype-builtins for safe prototype calls or other members" {
    const source =
        \\Object.prototype.hasOwnProperty.call(foo, "bar");
        \\Object.prototype.propertyIsEnumerable.call(foo, "bar");
        \\foo.hasOwn("bar");
        \\foo[method]("bar");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_prototype_builtins.id));
}

test "can disable no-prototype-builtins" {
    const source =
        \\foo.hasOwnProperty("bar");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_prototype_builtins = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_prototype_builtins.id));
}
