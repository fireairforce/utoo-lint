const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const rule_id = lint.rules.jest_valid_expect.id;

test "jest valid expect reports invalid argument counts matcher chains and modifiers" {
    const source =
        \\expect().toBe(true);
        \\expect(1, 2).toEqual(1);
        \\expect('value');
        \\expect(true).toBeDefined;
        \\expect(true).not;
        \\expect(true).nope.toBeDefined();
        \\expect(true).not.resolves.toBeDefined();
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, rule_id));
    try expectMessage(result, "Expect requires at least 1 argument");
    try expectMessage(result, "Expect takes at most 1 argument");
    try expectMessage(result, "Expect must have a corresponding matcher call");
    try expectMessage(result, "Matchers must be called to assert");
    try expectMessage(result, "Expect has an unknown modifier");

    try std.testing.expectEqualStrings("(", source[result.diagnostics[0].span.start..result.diagnostics[0].span.end]);
    try std.testing.expectEqualStrings("2", source[result.diagnostics[1].span.start..result.diagnostics[1].span.end]);
    try std.testing.expectEqualStrings("expect('value')", source[result.diagnostics[2].span.start..result.diagnostics[2].span.end]);
    try std.testing.expectEqualStrings("toBeDefined", source[result.diagnostics[3].span.start..result.diagnostics[3].span.end]);
}

test "jest valid expect allows valid matchers modifiers and static expect helpers" {
    const source =
        \\expect.hasAssertions;
        \\expect.hasAssertions();
        \\expect.extend({});
        \\expect(1).toBe(1);
        \\expect(undefined).not.toBeDefined();
        \\await expect(Promise.resolve(1)).resolves.toBe(1);
        \\await expect(Promise.reject(1)).rejects.not.toBe(2);
        \\expect(1)["toBe"](1);
        \\expect(1)[`toBe`](1);
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.mjs", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, rule_id));
}

test "jest valid expect requires async assertions and Promise wrappers to be awaited or returned" {
    const source =
        \\test('invalid', () => {
        \\  expect(Promise.resolve(1)).resolves.toBe(1);
        \\  expect(Promise.reject(1)).rejects.toBe(1);
        \\  expect(Promise.resolve(1)).toResolve();
        \\  expect(Promise.resolve(1)).resolves.toBe(1).then(() => {});
        \\  Promise.all([
        \\    (expect(Promise.resolve(1)).resolves.toBe(1)),
        \\    expect(Promise.resolve(2)).resolves.toBe(2),
        \\  ]);
        \\  Promise.resolve(expect(Promise.resolve(3)).resolves.toBe(3));
        \\});
        \\test('valid', async () => {
        \\  await expect(Promise.resolve(1)).resolves.toBe(1);
        \\  return expect(Promise.reject(1)).rejects.toBe(1);
        \\});
        \\test('arrow', () => expect(Promise.resolve(1)).resolves.toBe(1));
        \\test('then', () => { return expect(Promise.resolve(1)).resolves.toBe(1).then(() => {}); });
        \\test('wrappers', async () => {
        \\  await Promise.all([expect(Promise.resolve(1)).resolves.toBe(1)]);
        \\  await Promise.resolve(expect(Promise.resolve(2)).resolves.toBe(2));
        \\});
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, rule_id));
    try std.testing.expectEqualStrings("Async assertions must be awaited or returned", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("Promises which return async assertions must be awaited or returned", result.diagnostics[4].message);
    try std.testing.expectEqualStrings("Promises which return async assertions must be awaited or returned", result.diagnostics[5].message);
}

test "jest valid expect supports alwaysAwait and custom asyncMatchers" {
    const always_options = try optionsFromConfig(
        \\["error", {"alwaysAwait":true}]
    );
    const always_source =
        \\test('returned', () => { return expect(Promise.resolve(1)).resolves.toBe(1); });
        \\test('concise', () => expect(Promise.resolve(1)).resolves.toBe(1));
    ;
    var always_result = try lint.lintSource(std.testing.allocator, always_source, "fixture.js", always_options);
    defer always_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(always_result, rule_id));
    try std.testing.expectEqualStrings("Async assertions must be awaited", always_result.diagnostics[0].message);

    const custom_options = try optionsFromConfig(
        \\["error", {"asyncMatchers":["toSettle"]}]
    );
    const custom_source =
        \\expect(Promise.resolve(1)).toResolve();
        \\expect(Promise.resolve(1)).toSettle();
    ;
    var custom_result = try lint.lintSource(std.testing.allocator, custom_source, "fixture.js", custom_options);
    defer custom_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(custom_result, rule_id));
    try std.testing.expectEqualStrings("Async assertions must be awaited or returned", custom_result.diagnostics[0].message);
}

test "jest valid expect supports argument bounds options" {
    const options = try optionsFromConfig(
        \\["error", {"minArgs":0,"maxArgs":2}]
    );
    const source =
        \\expect().pass();
        \\expect(1, 'message').toBe(1);
        \\expect(1, 'message', 'extra').toBe(1);
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    try std.testing.expectEqualStrings("Expect takes at most 2 arguments", result.diagnostics[0].message);
}

test "jest valid expect supports imported required aliased and shadowed expect APIs" {
    const source =
        \\import { expect as assertion } from '@jest/globals';
        \\assertion(1);
        \\const { expect: check } = require('@jest/globals');
        \\check(true).toBeDefined;
        \\function local(expect) { expect(1); }
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, rule_id));

    var alias_options = optionsOnly();
    try std.testing.expect(alias_options.jest_global_aliases.append("expect", "verify"));
    var alias_result = try lint.lintSource(std.testing.allocator, "verify(1);", "fixture.js", alias_options);
    defer alias_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(alias_result, rule_id));
}

test "jest valid expect supports JavaScript TypeScript JSX and TSX" {
    const cases = [_]struct { source: []const u8, file_name: []const u8 }{
        .{ .source = "expect().toBe(true);", .file_name = "fixture.js" },
        .{ .source = "expect<boolean>().toBe(true);", .file_name = "fixture.ts" },
        .{ .source = "expect(<div />, 'message').toBeTruthy();", .file_name = "fixture.jsx" },
        .{ .source = "expect(<div /> as JSX.Element, 'message').toBeTruthy();", .file_name = "fixture.tsx" },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, case.file_name, optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    }
}

test "jest valid expect uses upstream defaults and accepts complete configuration" {
    const defaults = lint.Options{};
    try std.testing.expect(defaults.jest_valid_expect);
    try std.testing.expect(!defaults.jest_valid_expect_always_await);
    try std.testing.expect(defaults.jest_valid_expect_async_matchers.contains("toResolve"));
    try std.testing.expect(defaults.jest_valid_expect_async_matchers.contains("toReject"));
    try std.testing.expectEqual(@as(f64, 1), defaults.jest_valid_expect_min_args);
    try std.testing.expectEqual(@as(f64, 1), defaults.jest_valid_expect_max_args);

    var options = lint.Options.allDisabled();
    try std.testing.expect(options.setByCliName(rule_id, true));
    try std.testing.expect(options.jest_valid_expect);

    options = try optionsFromConfig(
        \\["error", {"alwaysAwait":true,"asyncMatchers":["toSettle"],"minArgs":2,"maxArgs":3}]
    );
    try std.testing.expect(options.jest_valid_expect_always_await);
    try std.testing.expect(options.jest_valid_expect_async_matchers.contains("toSettle"));
    try std.testing.expect(!options.jest_valid_expect_async_matchers.contains("toResolve"));
    try std.testing.expectEqual(@as(f64, 2), options.jest_valid_expect_min_args);
    try std.testing.expectEqual(@as(f64, 3), options.jest_valid_expect_max_args);
}

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.jest_valid_expect = true;
    return options;
}

fn optionsFromConfig(config: []const u8) !lint.Options {
    var options = optionsOnly();
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, config, .{});
    defer parsed.deinit();
    try options.setByRuleConfigValue(rule_id, parsed.value);
    return options;
}

fn expectMessage(result: lint.Result, expected: []const u8) !void {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id) and std.mem.eql(u8, diagnostic.message, expected)) return;
    }
    return error.TestExpectedEqual;
}
