const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports prefer-numeric-literals for parseInt calls that can be numeric literals" {
    const source =
        \\parseInt("101", 2);
        \\parseInt("755", 8);
        \\Number.parseInt("ff", 16);
        \\Number["parseInt"]("ff", 16);
        \\Number[`parseInt`]("ff", 16);
        \\parseInt?.("101", 2);
        \\Number.parseInt?.("ff", 16);
        \\Number?.parseInt("ff", 16);
        \\Number?.["parseInt"]("ff", 16);
        \\Number?.[`parseInt`]("ff", 16);
        \\parseInt(`a0`, 16);
        \\function local(parseInt, Number) {
        \\  parseInt("101", 2);
        \\  Number.parseInt("ff", 16);
        \\  Number["parseInt"]("ff", 16);
        \\  Number[`parseInt`]("ff", 16);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
        .typescript_eslint_dot_notation = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 15), helpers.countRule(result, lint.rules.prefer_numeric_literals.id));
    try std.testing.expectEqualStrings("Use a binary literal instead of parseInt().", result.diagnostics[0].message);
}

test "reports prefer-numeric-literals for static strings even when digits are invalid" {
    const source =
        \\parseInt("102", 2);
        \\parseInt("89", 8);
        \\parseInt("10px", 16);
        \\parseInt("", 16);
        \\parseInt(`7999`, 8);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.prefer_numeric_literals.id));
}

test "allows parseInt calls without static string and binary octal or hexadecimal radix" {
    const source =
        \\parseInt("101", 10);
        \\parseInt(value, 16);
        \\parseInt(`a${value}`, 16);
        \\parseInt("101", radix);
        \\parseInt("101", 2, extra);
        \\Number[`parse${suffix}`]("ff", 16);
        \\Number?.[`parse${suffix}`]("ff", 16);
        \\other.parseInt("ff", 16);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_numeric_literals.id));
}

test "can disable prefer-numeric-literals" {
    const source = "parseInt(\"101\", 2);\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .prefer_numeric_literals = false,
        .no_undef = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_numeric_literals.id));
}
