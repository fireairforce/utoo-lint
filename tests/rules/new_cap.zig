const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports new-cap for lowercase constructors and uppercase function calls" {
    const source =
        \\new foo();
        \\new namespace.foo();
        \\Foo();
        \\namespace.Foo();
        \\namespace["Foo"]();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.new_cap.id));
}

test "does not report new-cap for conventional constructor usage or callable builtins" {
    const source =
        \\new Foo();
        \\foo();
        \\new namespace.Foo();
        \\Array();
        \\Boolean();
        \\Date();
        \\Error();
        \\Number();
        \\Object();
        \\RegExp();
        \\String();
        \\Symbol();
        \\BigInt();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.new_cap.id));
}

test "can disable new-cap" {
    const source =
        \\new foo();
        \\Foo();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .new_cap = false,
        .no_new = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.new_cap.id));
}
