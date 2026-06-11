const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-new-require for constructing require calls" {
    const source =
        \\const foo = new require("foo");
        \\const bar = new (require)("bar");
        \\const baz = new (require("baz"));
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_new_require.id));
}

test "does not report no-new-require for ordinary require or constructed values" {
    const source =
        \\const Foo = require("foo");
        \\const foo = new Foo();
        \\const resolved = require.resolve("foo");
        \\const custom = new require.resolve("foo");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_new_require.id));
}

test "can disable no-new-require" {
    const source =
        \\const foo = new require("foo");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new_require = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_new_require.id));
}
