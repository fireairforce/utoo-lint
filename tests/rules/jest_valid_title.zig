const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const rule_id = lint.rules.jest_valid_title.id;

test "reports invalid titles with upstream messages and useful locations" {
    const cases = [_]struct { source: []const u8, message: []const u8, reported: []const u8 }{
        .{ .source = "describe('', () => {});", .message = "describe should not have an empty title", .reported = "describe('', () => {})" },
        .{ .source = "it(123, () => {});", .message = "Title must be a string", .reported = "123" },
        .{ .source = "test(' test title', () => {});", .message = "should not have leading or trailing spaces", .reported = "' test title'" },
        .{ .source = "xit('it works', () => {});", .message = "should not have duplicate prefix", .reported = "'it works'" },
        .{ .source = "test.each([])('%Q', () => {});", .message = "\"%Q\" is not a valid format specifier", .reported = "'%Q'" },
    };
    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, "fixture.js", optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
        const diagnostic = findDiagnostic(result).?;
        try std.testing.expectEqualStrings(case.message, diagnostic.message);
        try std.testing.expectEqualStrings(case.reported, case.source[diagnostic.span.start..diagnostic.span.end]);
    }
}

test "allows valid aliases templates binary titles and dynamic templates" {
    const source =
        \\describe('suite', () => {});
        \\fdescribe(`focused suite`, () => {});
        \\xdescribe('skipped suite', () => {});
        \\test('works', () => {});
        \\xtest(`skips`, () => {});
        \\it('runs', () => {});
        \\fit('focuses', () => {});
        \\xit('skips', () => {});
        \\it('is' + ' a string', () => {});
        \\it(1 + ' + ' + 1, () => {});
        \\test(`${dynamic} title`, () => {});
        \\someFn('', () => {});
        \\function local(test) { test('', () => {}); }
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, rule_id));
}

test "supports disallowedWords and type-ignore options" {
    const source =
        \\describe(makeName(), () => {});
        \\it(testName, () => {});
        \\test('the correct way', () => {});
        \\it('correctly works', () => {});
        \\xdescribe('has ALL things', () => {});
    ;
    const options = try optionsFromConfig(
        \\["error",{"ignoreTypeOfDescribeName":true,"ignoreTypeOfTestName":true,"disallowedWords":["correct","all"]}]
    );
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, rule_id));
    try std.testing.expectEqualStrings("\"correct\" is not allowed in test titles", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("\"ALL\" is not allowed in test titles", result.diagnostics[1].message);
}

test "preserves grouped mustMatch and mustNotMatch options and custom messages" {
    const source =
        \\describe('suite #unit', () => {});
        \\test('that works #unit', () => {});
        \\it('does not start correctly #jest4life', () => {});
        \\it('does not start correctly', () => {});
    ;
    const options = try optionsFromConfig(
        \\["error",{
        \\  "mustMatch":{"test":["^that","Test titles must start with that"],"it":"^that"},
        \\  "mustNotMatch":"(?:#(?!unit|e2e))\\w+"
        \\}]
    );
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, rule_id));
    try std.testing.expectEqualStrings("it should not match /(?:#(?!unit|e2e))\\w+/u", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("it should match /^that/u", result.diagnostics[1].message);

    const custom = try optionsFromConfig(
        \\["error",{"mustMatch":{"describe":["^when","Describe title needs context"]}}]
    );
    var custom_result = try lint.lintSource(std.testing.allocator, "describe('suite', () => {});", "fixture.js", custom);
    defer custom_result.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("Describe title needs context", findDiagnostic(custom_result).?.message);
}

test "checks only array each printf specifiers" {
    const valid =
        \\it.each([])('%p %s %d %i %f %j %o %# %$ %%', () => {});
        \\test.only.each(entries)('%%%i', () => {});
        \\describe.each([])('$value', () => {});
        \\it.each`value | expected`('%Q is literal for tagged each', () => {});
    ;
    var valid_result = try lint.lintSource(std.testing.allocator, valid, "fixture.js", optionsOnly());
    defer valid_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(valid_result, rule_id));

    const invalid =
        \\it.each([])('%Y', () => {});
        \\test.each(entries)('%i + %x', () => {});
        \\describe.skip.each([])('%%y + %z', () => {});
    ;
    var invalid_result = try lint.lintSource(std.testing.allocator, invalid, "fixture.js", optionsOnly());
    defer invalid_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(invalid_result, rule_id));
}

test "applies upstream-safe whitespace and duplicate-prefix autofixes" {
    const source =
        \\describe(' describe suite ', () => {
        \\  test(` test works  `, () => {});
        \\  it('it behaves', () => {});
        \\});
    ;
    const expected =
        \\describe('suite', () => {
        \\  test(`works`, () => {});
        \\  it('behaves', () => {});
        \\});
    ;
    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, rule_id));
}

test "ignoreSpaces disables whitespace diagnostics and fixes" {
    const options = try optionsFromConfig(
        \\["error",{"ignoreSpaces":true}]
    );
    var result = try lint.lintSource(std.testing.allocator, "test(' title ', () => {});", "fixture.js", options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, rule_id));
}

test "supports imported required and configured aliases" {
    const imported =
        \\import { describe as context, test as testThat, it as spec } from '@jest/globals';
        \\context('describe duplicate', () => {});
        \\testThat('test duplicate', () => {});
        \\spec('it duplicate', () => {});
    ;
    var imported_result = try lint.lintSource(std.testing.allocator, imported, "fixture.js", optionsOnly());
    defer imported_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(imported_result, rule_id));

    const required =
        \\const { describe: context, test: testThat } = require('@jest/globals');
        \\context('', () => {});
        \\testThat(123, () => {});
    ;
    var required_result = try lint.lintSource(std.testing.allocator, required, "fixture.js", optionsOnly());
    defer required_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(required_result, rule_id));

    var alias_options = optionsOnly();
    try std.testing.expect(alias_options.jest_global_aliases.append("describe", "suite"));
    try std.testing.expect(alias_options.jest_global_aliases.append("test", "spec"));
    var alias_result = try lint.lintSource(std.testing.allocator, "suite('', () => {}); spec(1, () => {});", "fixture.js", alias_options);
    defer alias_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(alias_result, rule_id));
}

test "supports JavaScript TypeScript JSX and TSX" {
    const cases = [_]struct { source: []const u8, file_name: []const u8 }{
        .{ .source = "test('test js ', () => {});", .file_name = "fixture.js" },
        .{ .source = "test('test ts ', (): void => {});", .file_name = "fixture.ts" },
        .{ .source = "test('test jsx ', () => <div />);", .file_name = "fixture.jsx" },
        .{ .source = "test('test tsx ', (): JSX.Element => <div />);", .file_name = "fixture.tsx" },
    };
    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, case.file_name, optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, rule_id));
        try std.testing.expect(result.diagnostics[0].fixes.len != 0);
        try std.testing.expect(result.diagnostics[1].fixes.len != 0);
    }
}

test "uses recommended defaults accepts CLI name and parses every option shape" {
    try std.testing.expect((lint.Options{}).jest_valid_title);
    var options = lint.Options.allDisabled();
    try std.testing.expect(options.setByCliName(rule_id, true));
    try std.testing.expect(options.jest_valid_title);

    options = try optionsFromConfig(
        \\["error",{
        \\  "ignoreSpaces":true,
        \\  "ignoreTypeOfDescribeName":true,
        \\  "ignoreTypeOfTestName":true,
        \\  "disallowedWords":["all","every"],
        \\  "mustNotMatch":["\\.$","No full stops"],
        \\  "mustMatch":{"describe":"^when","test":["^that"],"it":["^it","Start with it"]}
        \\}]
    );
    try std.testing.expect(options.jest_valid_title_ignore_spaces);
    try std.testing.expect(options.jest_valid_title_ignore_type_of_describe_name);
    try std.testing.expect(options.jest_valid_title_ignore_type_of_test_name);
    try std.testing.expectEqual(@as(usize, 2), options.jest_valid_title_disallowed_words.count);
    try std.testing.expectEqualStrings("all", options.jest_valid_title_disallowed_words.at(0));
    try std.testing.expectEqualStrings("\\.$", options.jest_valid_title_must_not_match.describe.pattern().?);
    try std.testing.expectEqualStrings("No full stops", options.jest_valid_title_must_not_match.it.message().?);
    try std.testing.expectEqualStrings("^when", options.jest_valid_title_must_match.describe.pattern().?);
    try std.testing.expectEqualStrings("^that", options.jest_valid_title_must_match.test_case.pattern().?);
    try std.testing.expectEqualStrings("Start with it", options.jest_valid_title_must_match.it.message().?);
}

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.jest_valid_title = true;
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
