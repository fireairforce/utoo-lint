const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports prefer-template for string concatenation with expressions" {
    const source =
        \\const a = "hello " + name;
        \\const b = name + "!";
        \\const c = `hello ` + name;
        \\const d = `hello ${name}` + suffix;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.prefer_template.id));
}

test "does not report prefer-template for non-string or static-only concatenation" {
    const source =
        \\const a = left + right;
        \\const b = "hello " + "world";
        \\const c = `hello ` + "world";
        \\const d = `hello ${name}`;
        \\const e = `hello ${name}` + "!";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_useless_concat = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_template.id));
}

test "can disable prefer-template" {
    const source =
        \\const value = "hello " + name;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .prefer_template = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_template.id));
}
