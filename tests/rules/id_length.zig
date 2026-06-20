const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports short binding identifiers" {
    const source =
        \\function f(a, goodName) {
        \\  const b = goodName;
        \\  return b;
        \\}
        \\const [c, { d: e, f: goodValue }] = list;
        \\try {} catch (g) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.id_length.id));
    try std.testing.expect(hasMessage(result, "Identifier name 'f' is too short (< 2)."));
    try std.testing.expect(hasMessage(result, "Identifier name 'e' is too short (< 2)."));
}

test "reports property names when configured" {
    const source =
        \\class C {
        \\  #x;
        \\  y() {}
        \\  longName() {}
        \\}
        \\const obj = { z: 1, okName: 2, [computed]: 3 };
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.id_length.id));
    try std.testing.expect(hasMessage(result, "Identifier name '#x' is too short (< 2)."));
}

test "can ignore property names" {
    const source =
        \\class GoodName {
        \\  #x;
        \\  y() {}
        \\  z = 1;
        \\}
        \\const obj = { a: 1 };
    ;

    var options = baseOptions();
    options.id_length_properties = .never;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.id_length.id));
}

test "supports maximum, exceptions, and exception patterns" {
    const source =
        \\const x = 1;
        \\const ok = 2;
        \\const tooLongName = 3;
        \\const endLong = 4;
        \\const no = 5;
    ;

    var options = baseOptions();
    options.id_length_min = 3;
    options.id_length_has_max = true;
    options.id_length_max = 5;
    try options.id_length_exceptions.append("x");
    try options.id_length_exception_patterns.append("^ok");
    try options.id_length_exception_patterns.append("Long$");

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.id_length.id));
    try std.testing.expect(hasMessage(result, "Identifier name 'tooLongName' is too long (> 5)."));
    try std.testing.expect(hasMessage(result, "Identifier name 'no' is too short (< 3)."));
}

test "reports import aliases but skips unrenamed named imports" {
    const source =
        \\import x, { foo as y, bar } from "pkg";
        \\import * as n from "other";
        \\bar;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.id_length.id));
}

test "parses eslint id-length config" {
    var parsed = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"min\":3,\"max\":8,\"exceptions\":[\"x\"],\"exceptionPatterns\":[\"^ok\"],\"properties\":\"never\"}]",
        .{},
    );
    defer parsed.deinit();

    var options = baseOptions();
    try options.setByRuleConfigValue("id-length", parsed.value);

    try std.testing.expect(options.id_length);
    try std.testing.expectEqual(@as(usize, 3), options.id_length_min);
    try std.testing.expect(options.id_length_has_max);
    try std.testing.expectEqual(@as(usize, 8), options.id_length_max);
    try std.testing.expectEqual(@as(@TypeOf(options.id_length_properties), .never), options.id_length_properties);
    try std.testing.expect(options.id_length_exceptions.contains("x"));
    try std.testing.expect(options.id_length_exception_patterns.matches("okay"));
}

test "can disable id-length" {
    const source =
        \\const x = 1;
    ;

    var options = baseOptions();
    options.id_length = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.id_length.id));
}

fn baseOptions() lint.Options {
    return .{
        .id_length = true,
        .consistent_return = false,
        .import_no_unresolved = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .typescript_eslint_no_empty_function = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.id_length.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
