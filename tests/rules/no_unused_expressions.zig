const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-unused-expressions for expressions without side effects" {
    const source =
        \\foo;
        \\1;
        \\`text`;
        \\foo + bar;
        \\foo && bar();
        \\foo ? bar() : baz();
        \\obj.prop;
        \\[foo];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 8), helpers.countRule(result, lint.rules.no_unused_expressions.id));
}

test "does not report no-unused-expressions for expressions with side effects" {
    const source =
        \\foo();
        \\foo?.();
        \\new Foo();
        \\value = 1;
        \\value += 1;
        \\value++;
        \\tag`template`;
        \\import("mod");
        \\(foo());
        \\(0, foo());
        \\async function run() {
        \\  await foo();
        \\}
        \\function* gen() {
        \\  yield value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new = false,
        .no_undef = false,
        .no_unused_vars = false,
        .no_plusplus = false,
        .no_sequences = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unused_expressions.id));
}

test "can disable no-unused-expressions" {
    const source =
        \\foo;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_expressions = false,
        .no_undef = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unused_expressions.id));
}
