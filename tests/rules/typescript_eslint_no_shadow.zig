const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-shadow for TypeScript value and type shadows" {
    const source =
        \\const value = 1;
        \\type Box = {};
        \\interface Shape {}
        \\declare const ambient: string;
        \\function f(value: number) {
        \\  type Box = {};
        \\  interface Shape {}
        \\  return value;
        \\}
        \\function g<Box>() {
        \\  return null as Box;
        \\}
        \\function h(ambient: string) {
        \\  return ambient;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .typescript_eslint_consistent_type_definitions = false,
        .typescript_eslint_no_empty_interface = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.typescript_eslint_no_shadow.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_shadow.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.typescript_eslint_no_shadow.id)) {
            try std.testing.expectEqual(lint.Severity.@"error", diagnostic.severity);
        }
    }
}

test "allows @typescript-eslint/no-shadow TypeScript class interface merging" {
    const source =
        \\class Model {}
        \\function f() {
        \\  interface Model {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .typescript_eslint_no_empty_interface = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_shadow.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_shadow.id));
}

test "supports configured @typescript-eslint/no-shadow allow names" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allow\":[\"value\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("@typescript-eslint/no-shadow", config.value);
    options.no_unused_vars = false;
    options.typescript_eslint_no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\const value = 1;
        \\const other = 2;
        \\function f(value: number) {
        \\  return value;
        \\}
        \\function g(other: number) {
        \\  return other;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_no_shadow.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_shadow.id));
}

test "supports configured @typescript-eslint/no-shadow built-in globals" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"builtinGlobals\":true,\"allow\":[\"Object\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("@typescript-eslint/no-shadow", config.value);
    options.no_unused_vars = false;
    options.typescript_eslint_no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\function allowed(Object: unknown) {
        \\  return Object;
        \\}
        \\function reported(Array: unknown) {
        \\  return Array;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_no_shadow.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_shadow.id));
}

test "can disable @typescript-eslint/no-shadow and fall back to no-shadow" {
    const source =
        \\const value = 1;
        \\function f(value: number) {
        \\  return value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .typescript_eslint_no_shadow = false,
        .no_unused_vars = false,
        .typescript_eslint_no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_shadow.id));
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_shadow.id));
}
