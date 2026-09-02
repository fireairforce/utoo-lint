const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const rule_id = lint.rules.jest_no_standalone_expect.id;
const expected_message = "Expect must be inside of a test block";

test "reports standalone expects and suite-body expects with useful locations" {
    const cases = [_]struct {
        source: []const u8,
        reported: []const u8,
    }{
        .{ .source = "expect(1).toBe(1);", .reported = "expect(1).toBe(1)" },
        .{ .source = "{ expect(1).toBe(1); }", .reported = "expect(1).toBe(1)" },
        .{ .source = "describe('suite', () => { expect(1).toBe(1); });", .reported = "expect(1).toBe(1)" },
        .{ .source = "describe('suite', () => expect(1).toBe(1));", .reported = "expect(1).toBe(1)" },
        .{ .source = "beforeEach(() => expect.hasAssertions());", .reported = "expect.hasAssertions()" },
        .{ .source = "run(() => expect(true).toBe(false));", .reported = "expect(true).toBe(false)" },
        .{ .source = "expect().hasAssertions();", .reported = "expect().hasAssertions()" },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, "fixture.js", optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
        const diagnostic = findDiagnostic(result).?;
        try std.testing.expectEqualStrings(expected_message, diagnostic.message);
        try std.testing.expectEqualStrings(case.reported, case.source[diagnostic.span.start..diagnostic.span.end]);
    }
}

test "allows expect calls in tests and helper functions" {
    const source =
        \\describe('suite', () => {
        \\  it('works', () => { expect(1).toBe(1); });
        \\  test.only('only', () => expect(true).toBe(true));
        \\  test.concurrent('concurrent', () => expect(true).toBe(true));
        \\  it.each([1, 2])('each', value => expect(value).toBeTruthy());
        \\  function declaredHelper() { expect(1).toBe(1); }
        \\  const arrowHelper = () => { expect(1).toBe(1); };
        \\  const functionHelper = function () { expect(1).toBe(1); };
        \\});
        \\const topLevelArrow = () => expect(1).toBe(1);
        \\const topLevelFunction = function () { expect(1).toBe(1); };
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, rule_id));
}

test "allows standalone asymmetric helpers but checks assertion-count methods" {
    const source =
        \\expect.any(String);
        \\expect.extend({});
        \\expect.arrayContaining([]);
        \\expect.assertions(1);
        \\expect.hasAssertions();
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, rule_id));
    try std.testing.expectEqualStrings("expect.assertions(1)", source[result.diagnostics[0].span.start..result.diagnostics[0].span.end]);
    try std.testing.expectEqualStrings("expect.hasAssertions()", source[result.diagnostics[1].span.start..result.diagnostics[1].span.end]);
}

test "does not leak test context after modified and parameterized tests" {
    const source =
        \\it.only('only', () => expect(true).toBe(true));
        \\expect('after only').toBe(true);
        \\it.each([1])('each', value => expect(value).toBe(1));
        \\expect('after each').toBe(true);
        \\it.each`value\n${1}`('tagged', value => expect(value).toBe(1));
        \\expect('after tagged').toBe(true);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, rule_id));
}

test "reports hooks but allows nested callbacks executing in a test" {
    const source =
        \\beforeAll(() => expect(true).toBe(true));
        \\beforeEach(() => expect(true).toBe(true));
        \\afterEach(() => expect(true).toBe(true));
        \\afterAll(() => expect(true).toBe(true));
        \\it('async work', () => promise.then(() => expect(true).toBe(true)));
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, rule_id));
}

test "supports additionalTestBlockFunctions including chained names" {
    const source =
        \\const t = Math.random() ? it.only : it;
        \\t('custom', () => expect(true).toBe(true));
        \\each([[1, 2]]).test('chained', (value, expected) => {
        \\  expect(value).toBe(expected);
        \\});
    ;

    var without_options = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer without_options.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(without_options, rule_id));

    var options = try optionsFromConfig(
        \\["error", {"additionalTestBlockFunctions":["t", "each.test"]}]
    );
    var configured = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer configured.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(configured, rule_id));

    options = try optionsFromConfig(
        \\["error", {"additionalTestBlockFunctions":["each"]}]
    );
    var partial = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer partial.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(partial, rule_id));
}

test "supports imported required and configured Jest APIs" {
    const imported =
        \\import { describe as suite, expect as pleaseExpect, it as spec } from '@jest/globals';
        \\suite('group', () => pleaseExpect(true).toBe(true));
        \\spec('works', () => pleaseExpect(true).toBe(true));
    ;
    var imported_result = try lint.lintSource(std.testing.allocator, imported, "fixture.js", optionsOnly());
    defer imported_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(imported_result, rule_id));

    const required =
        \\const { expect: check, test: verify } = require('@jest/globals');
        \\verify('works', () => check(true).toBe(true));
        \\check(true).toBe(true);
    ;
    var required_result = try lint.lintSource(std.testing.allocator, required, "fixture.js", optionsOnly());
    defer required_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(required_result, rule_id));

    var alias_options = optionsOnly();
    try std.testing.expect(alias_options.jest_global_aliases.append("describe", "suite"));
    try std.testing.expect(alias_options.jest_global_aliases.append("test", "spec"));
    try std.testing.expect(alias_options.jest_global_aliases.append("expect", "check"));
    const aliases =
        \\suite('group', () => check(true).toBe(true));
        \\spec('works', () => check(true).toBe(true));
    ;
    var alias_result = try lint.lintSource(std.testing.allocator, aliases, "fixture.js", alias_options);
    defer alias_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(alias_result, rule_id));
}

test "ignores a shadowed expect binding" {
    const source = "function run(expect) { expect(true).toBe(true); }";
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, rule_id));
}

test "supports JavaScript TypeScript JSX and TSX" {
    const cases = [_]struct { source: []const u8, file_name: []const u8 }{
        .{ .source = "expect(value).toBe(true);", .file_name = "fixture.js" },
        .{ .source = "expect(value as boolean).toBe(true);", .file_name = "fixture.ts" },
        .{ .source = "expect(<div />).toBeTruthy();", .file_name = "fixture.jsx" },
        .{ .source = "expect(<div /> as JSX.Element).toBeTruthy();", .file_name = "fixture.tsx" },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, case.file_name, optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    }
}

test "uses the recommended default and accepts rule configuration" {
    try std.testing.expect((lint.Options{}).jest_no_standalone_expect);

    var options = lint.Options.allDisabled();
    try std.testing.expect(options.setByCliName(rule_id, true));
    try std.testing.expect(options.jest_no_standalone_expect);

    options = try optionsFromConfig(
        \\["error", {"additionalTestBlockFunctions":["customTest"]}]
    );
    try std.testing.expect(options.jest_no_standalone_expect);
    try std.testing.expectEqual(@as(usize, 1), options.jest_no_standalone_expect_additional_test_block_functions.count);
    try std.testing.expectEqualStrings("customTest", options.jest_no_standalone_expect_additional_test_block_functions.at(0));
}

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.jest_no_standalone_expect = true;
    return options;
}

fn optionsFromConfig(config: []const u8) !lint.Options {
    var options = optionsOnly();
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, config, .{});
    defer parsed.deinit();
    try options.setByRuleConfigValue(rule_id, parsed.value);
    return options;
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id)) return diagnostic;
    }
    return null;
}
