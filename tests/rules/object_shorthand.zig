const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports object-shorthand for redundant property and method forms" {
    const source =
        \\const foo = 1;
        \\const obj = {
        \\  foo: foo,
        \\  bar: function () {
        \\    return 1;
        \\  },
        \\  asyncValue: async function () {
        \\    return 2;
        \\  },
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.object_shorthand.id));
}

test "does not report object-shorthand for non-shorthandable properties" {
    const source =
        \\const foo = 1;
        \\const obj = {
        \\  foo,
        \\  foo: bar,
        \\  "foo": foo,
        \\  [foo]: foo,
        \\  bar: function named() {
        \\    return 1;
        \\  },
        \\  get value() {
        \\    return foo;
        \\  },
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.object_shorthand.id));
}

test "can disable object-shorthand" {
    const source =
        \\const obj = {
        \\  foo: foo,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .object_shorthand = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.object_shorthand.id));
}
