const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const base_options = lint.Options{
    .no_magic_numbers = true,
    .no_undef = false,
    .no_unused_vars = false,
    .parser_semantic_errors = false,
};

fn count(source: []const u8, file_name: []const u8, options: lint.Options) !usize {
    var result = try lint.lintSource(std.testing.allocator, source, file_name, options);
    defer result.deinit(std.testing.allocator);
    return helpers.countRule(result, lint.rules.no_magic_numbers.id);
}

test "matches default JavaScript behavior" {
    const valid = [_][]const u8{
        "var x = parseInt(y, 10);",
        "var x = Number.parseInt(y, -10);",
        "const answer = +42;",
        "var answer = -42;",
        "var object = { answer: 42, 42: 'key' };",
        "object.answer = 42;",
        "var jsx = <input maxLength={10} />;",
    };
    for (valid) |source| try std.testing.expectEqual(@as(usize, 0), try count(source, "fixture.jsx", base_options));

    const invalid = [_]struct { source: []const u8, expected: usize }{
        .{ .source = "var value = 0 + 1 + -2;", .expected = 3 },
        .{ .source = "value = 5; value += 6;", .expected = 2 },
        .{ .source = "function seconds() { return -60; }", .expected = 1 },
        .{ .source = "var jsx = <div values={[1, 2, 3]} />;", .expected = 3 },
    };
    for (invalid) |case| try std.testing.expectEqual(case.expected, try count(case.source, "fixture.jsx", base_options));
}

test "supports enforceConst and detectObjects" {
    var options = base_options;
    options.no_magic_numbers_enforce_const = true;
    try std.testing.expectEqual(@as(usize, 1), try count("let answer = 42;", "fixture.js", options));
    try std.testing.expectEqual(@as(usize, 0), try count("const answer = 42;", "fixture.js", options));

    options = base_options;
    options.no_magic_numbers_detect_objects = true;
    try std.testing.expectEqual(@as(usize, 3), try count("var object = { 42: 42 }; object.answer = 43;", "fixture.js", options));
}

test "supports ignored Number and BigInt values" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"ignore\":[0,1,-2,\"100n\",\"-200n\"]}]",
        .{},
    );
    defer config.deinit();

    var options = base_options;
    try options.setByRuleConfigValue("no-magic-numbers", config.value);
    try std.testing.expectEqual(@as(usize, 0), try count("f(0, 1, -2, 100n, -200n, 0x64n);", "fixture.js", options));
    try std.testing.expectEqual(@as(usize, 3), try count("f(2, -100n, 200n);", "fixture.js", options));
}

test "parses every official object option" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"detectObjects\":true,\"enforceConst\":true,\"ignoreArrayIndexes\":true,\"ignoreDefaultValues\":true,\"ignoreClassFieldInitialValues\":true,\"ignoreEnums\":true,\"ignoreNumericLiteralTypes\":true,\"ignoreReadonlyClassProperties\":true,\"ignoreTypeIndexes\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-magic-numbers", config.value);
    try std.testing.expect(options.no_magic_numbers);
    try std.testing.expect(options.no_magic_numbers_detect_objects);
    try std.testing.expect(options.no_magic_numbers_enforce_const);
    try std.testing.expect(options.no_magic_numbers_ignore_array_indexes);
    try std.testing.expect(options.no_magic_numbers_ignore_default_values);
    try std.testing.expect(options.no_magic_numbers_ignore_class_field_initial_values);
    try std.testing.expect(options.no_magic_numbers_ignore_enums);
    try std.testing.expect(options.no_magic_numbers_ignore_numeric_literal_types);
    try std.testing.expect(options.no_magic_numbers_ignore_readonly_class_properties);
    try std.testing.expect(options.no_magic_numbers_ignore_type_indexes);
}

test "validates actual array index values" {
    var options = base_options;
    options.no_magic_numbers_ignore_array_indexes = true;

    const valid = [_][]const u8{
        "foo[-0]",  "foo[1]",     "foo[200.00]",      "foo[3e4]",   "foo[0xABC]", "foo[4294967294]",
        "foo[-0n]", "foo[0xABn]", "foo[4294967294n]", "foo?.[777]",
    };
    for (valid) |source| try std.testing.expectEqual(@as(usize, 0), try count(source, "fixture.js", options));

    const invalid = [_][]const u8{
        "foo[-1]", "foo[1.5]", "foo[4294967295]", "foo[1e310]", "foo[-1n]", "foo[4294967295n]",
    };
    for (invalid) |source| try std.testing.expectEqual(@as(usize, 1), try count(source, "fixture.js", options));
}

test "supports defaults and class field initial values" {
    var options = base_options;
    options.no_magic_numbers_ignore_default_values = true;
    try std.testing.expectEqual(@as(usize, 0), try count("const f = ({ value = 123 }, other = -2) => {};", "fixture.js", options));
    try std.testing.expectEqual(@as(usize, 2), try count("const f = ({ value = 1 + 2 }) => {};", "fixture.js", options));

    options = base_options;
    options.no_magic_numbers_ignore_class_field_initial_values = true;
    try std.testing.expectEqual(@as(usize, 0), try count("class C { foo = 2; static #bar = -3; }", "fixture.js", options));
    try std.testing.expectEqual(@as(usize, 2), try count("class C { foo = 2 + 3; }", "fixture.js", options));
}

test "supports TypeScript-specific ignore options" {
    var options = base_options;
    options.no_magic_numbers_ignore_enums = true;
    try std.testing.expectEqual(@as(usize, 0), try count("enum E { A = 1000, B = -1, C = +2 }", "fixture.ts", options));

    options = base_options;
    options.no_magic_numbers_ignore_numeric_literal_types = true;
    try std.testing.expectEqual(@as(usize, 0), try count("type Value = 1 | -2 | (3);", "fixture.ts", options));
    try std.testing.expectEqual(@as(usize, 1), try count("interface Value { item: 1; }", "fixture.ts", options));

    options = base_options;
    options.no_magic_numbers_ignore_readonly_class_properties = true;
    try std.testing.expectEqual(@as(usize, 0), try count("class C { readonly a = 1; static readonly b = -2; }", "fixture.ts", options));

    options = base_options;
    options.no_magic_numbers_ignore_type_indexes = true;
    try std.testing.expectEqual(@as(usize, 0), try count("type Value = Source[((1 & -2) | 3) | 4];", "fixture.ts", options));
    try std.testing.expectEqual(@as(usize, 4), try count("type Value = { [K in 0 | 1 | 2]: 3 };", "fixture.ts", options));
}

test "uses official messages and is disabled by default" {
    var options = base_options;
    options.no_magic_numbers_enforce_const = true;
    var result = try lint.lintSource(std.testing.allocator, "let answer = 42; returnValue(7);", "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    var saw_const = false;
    var saw_magic = false;
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_magic_numbers.id)) continue;
        if (std.mem.eql(u8, diagnostic.message, "Number constants declarations must use 'const'.")) saw_const = true;
        if (std.mem.eql(u8, diagnostic.message, "No magic number: 7.")) saw_magic = true;
    }
    try std.testing.expect(saw_const and saw_magic);

    try std.testing.expectEqual(@as(usize, 0), try count("returnValue(7);", "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    }));
}
