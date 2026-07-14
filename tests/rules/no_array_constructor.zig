const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-array-constructor for disallowed Array constructor usage" {
    const source =
        \\const a = Array();
        \\const b = new Array();
        \\const c = Array(1, 2);
        \\const d = new Array("a", "b");
        \\const e = Array(...items);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_array_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_array_constructor.id));
}

test "does not report no-array-constructor for single non-spread argument or shadowed Array" {
    const source =
        \\const a = Array(length);
        \\const b = new Array(10);
        \\function local(Array) {
        \\  const c = Array();
        \\  const d = new Array(1, 2);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_array_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_array_constructor.id));
}

test "autofixes Array constructors while preserving argument text" {
    const source =
        \\const a = Array();
        \\const b = new Array();
        \\const c = Array(1, 2);
        \\const d = new Array("a", "b");
        \\const e = Array(first, ...rest, last);
        \\const f = Array(1, /* keep */ 2);
    ;
    const expected =
        \\const a = [];
        \\const b = [];
        \\const c = [1, 2];
        \\const d = ["a", "b"];
        \\const e = [first, ...rest, last];
        \\const f = [1, /* keep */ 2];
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_array_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_array_constructor.id));
}

test "does not autofix Array constructors with unsafe call or comment boundaries" {
    const source =
        \\Array?.();
        \\Array(...items);
        \\Array(...items, last);
        \\new /* keep */ Array(1, 2);
        \\Array /* keep */ (1, 2);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_console = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_array_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!result.fixed);
    try std.testing.expectEqualStrings(source, result.output);
    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result.result, lint.rules.no_array_constructor.id));
}

test "autofix inserts an ASI guard only in statement lists" {
    const source =
        \\previous()
        \\Array()
        \\if (condition)
        \\  Array()
    ;
    const expected =
        \\previous()
        \\;[]
        \\if (condition)
        \\  []
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_console = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_array_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_array_constructor.id));
}

test "can disable no-array-constructor" {
    const source =
        \\const a = Array();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_array_constructor = false,
        .no_unused_vars = false,
        .no_undef = false,
        .typescript_eslint_no_array_constructor = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_array_constructor.id));
}
