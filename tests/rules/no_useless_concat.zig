const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-useless-concat for same line string literal concatenation" {
    const source =
        \\const first = "foo" + "bar";
        \\const second = `foo` + "bar";
        \\const third = "foo" + `bar`;
        \\const fourth = `foo` + `bar`;
        \\const fifth = `foo ${value}` + "bar";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_useless_concat.id));
}

test "does not report no-useless-concat for dynamic or multiline concatenation" {
    const source =
        \\const dynamic = "foo" + value;
        \\const multiline = "foo" +
        \\  "bar";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_concat.id));
}

test "can disable no-useless-concat" {
    const source =
        \\const value = "foo" + "bar";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_useless_concat = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_concat.id));
}
