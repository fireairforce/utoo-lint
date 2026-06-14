const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports default-param-last for default parameters before required parameters" {
    const source =
        \\function first(a = 1, b) {
        \\  return b;
        \\}
        \\const second = function (a, b = 1, c) {
        \\  return c;
        \\};
        \\const third = (a = 1, b) => b;
        \\class Example {
        \\  constructor(private a = 1, b: string) {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .func_names = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .typescript_eslint_no_empty_function = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.default_param_last.id));
    try std.testing.expectEqualStrings("Default parameters should be last.", result.diagnostics[0].message);
}

test "allows default parameters after required and before optional parameters" {
    const source =
        \\function first(a, b = 1) {
        \\  return b;
        \\}
        \\function second(a = 1, b?: string) {
        \\  return b;
        \\}
        \\const third = (a, b = 1, ...rest) => rest;
        \\class Example {
        \\  constructor(private a?: string, public b = "value") {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .eol_last = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .typescript_eslint_no_empty_function = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.default_param_last.id));
}

test "can disable default-param-last" {
    const source = "function first(a = 1, b) { return b; }\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .default_param_last = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.default_param_last.id));
}
