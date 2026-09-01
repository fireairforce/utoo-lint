const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const rule_id = lint.rules.jest_no_identical_title.id;

test "reports duplicate test and describe titles with useful locations" {
    const source =
        \\describe("root", () => {
        \\  it("same", () => {});
        \\  test.only("same", () => {});
        \\  describe("child", () => {});
        \\  fdescribe("child", () => {});
        \\});
        \\test.concurrent("top", () => {});
        \\xtest("top", () => {});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, rule_id));

    const diagnostics = ruleDiagnostics(result);
    try std.testing.expectEqualStrings("Test title is used multiple times in the same describe block", diagnostics[0].message);
    try std.testing.expectEqualStrings("\"same\"", source[diagnostics[0].span.start..diagnostics[0].span.end]);
    try std.testing.expectEqualStrings("Describe block title is used multiple times in the same describe block", diagnostics[1].message);
    try std.testing.expectEqualStrings("\"child\"", source[diagnostics[1].span.start..diagnostics[1].span.end]);
    try std.testing.expectEqualStrings("Test title is used multiple times in the same describe block", diagnostics[2].message);
    try std.testing.expectEqualStrings("\"top\"", source[diagnostics[2].span.start..diagnostics[2].span.end]);
}

test "keeps nested suites and test and describe namespaces separate" {
    const cases = [_][]const u8{
        "describe('same', () => {}); it('same', () => {});",
        \\describe("foo", () => {
        \\  it("works", () => {});
        \\  describe("child", () => {
        \\    it("works", () => {});
        \\  });
        \\});
        ,
        \\describe("foo", () => {
        \\  describe("child", () => {});
        \\});
        \\describe("child", () => {});
        ,
        "it(); it(); describe(); describe();",
        "expect('same'); expect('same');",
    };

    for (cases) |source| {
        var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expect(!helpers.hasRule(result, rule_id));
    }
}

test "compares static templates and ignores dynamic and each titles" {
    const source =
        \\it(`static title`, () => {});
        \\it("static title", () => {});
        \\it(`${value}`, () => {});
        \\it(`${value}`, () => {});
        \\test("number " + value, () => {});
        \\test("number " + value, () => {});
        \\describe.each([])("generated", () => {});
        \\describe.each([])("generated", () => {});
        \\test.each``("generated test", () => {});
        \\test.each``("generated test", () => {});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    const diagnostic = ruleDiagnostics(result)[0];
    try std.testing.expectEqualStrings("\"static title\"", source[diagnostic.span.start..diagnostic.span.end]);
}

test "supports imported Jest functions and configured global aliases" {
    const imported_source =
        \\import { describe as suite, test as check } from "@jest/globals";
        \\suite("group", () => {});
        \\suite("group", () => {});
        \\check("case", () => {});
        \\check("case", () => {});
    ;
    var imported_result = try lint.lintSource(std.testing.allocator, imported_source, "fixture.js", optionsOnly());
    defer imported_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(imported_result, rule_id));

    var options = optionsOnly();
    try std.testing.expect(options.jest_global_aliases.append("describe", "context"));
    const alias_source =
        \\context("group", () => {});
        \\describe("group", () => {});
    ;
    var alias_result = try lint.lintSource(std.testing.allocator, alias_source, "fixture.js", options);
    defer alias_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(alias_result, rule_id));
}

test "supports JavaScript TypeScript JSX and TSX" {
    const cases = [_]struct { source: []const u8, file_name: []const u8 }{
        .{ .source = "it('same', () => {}); it('same', () => {});", .file_name = "fixture.js" },
        .{ .source = "it('same', (): void => {}); it('same', (): void => {});", .file_name = "fixture.ts" },
        .{ .source = "it('same', () => <div />); it('same', () => <span />);", .file_name = "fixture.jsx" },
        .{ .source = "it('same', (): JSX.Element => <div />); it('same', (): JSX.Element => <span />);", .file_name = "fixture.tsx" },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, case.file_name, optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    }
}

test "uses the recommended default and accepts rule configuration" {
    try std.testing.expect((lint.Options{}).jest_no_identical_title);

    var options = lint.Options.allDisabled();
    try std.testing.expect(options.setByCliName(rule_id, true));
    try std.testing.expect(options.jest_no_identical_title);

    var config = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "\"error\"", .{});
    defer config.deinit();
    options.jest_no_identical_title = false;
    try options.setByRuleConfigValue(rule_id, config.value);
    try std.testing.expect(options.jest_no_identical_title);
}

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.jest_no_identical_title = true;
    return options;
}

fn ruleDiagnostics(result: lint.Result) []const lint.Diagnostic {
    var start: usize = 0;
    while (start < result.diagnostics.len and !std.mem.eql(u8, result.diagnostics[start].rule_id, rule_id)) : (start += 1) {}
    var end = start;
    while (end < result.diagnostics.len and std.mem.eql(u8, result.diagnostics[end].rule_id, rule_id)) : (end += 1) {}
    return result.diagnostics[start..end];
}
