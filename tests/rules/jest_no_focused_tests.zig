const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const rule_id = lint.rules.jest_no_focused_tests.id;

test "reports focused global calls with useful locations and suggestions" {
    const cases = [_]struct {
        source: []const u8,
        reported: []const u8,
        expected: []const u8,
    }{
        .{ .source = "describe.only()", .reported = "only", .expected = "describe()" },
        .{ .source = "describe.only.each()()", .reported = "only", .expected = "describe.each()()" },
        .{ .source = "describe.only.each`table`()", .reported = "only", .expected = "describe.each`table`()" },
        .{ .source = "describe[\"only\"]()", .reported = "\"only\"", .expected = "describe()" },
        .{ .source = "describe . only()", .reported = "only", .expected = "describe ()" },
        .{ .source = "describe [ \"only\" /* focus */ ]()", .reported = "\"only\"", .expected = "describe ()" },
        .{ .source = "it.concurrent.only.each``()", .reported = "only", .expected = "it.concurrent.each``()" },
        .{ .source = "test.concurrent.only()", .reported = "only", .expected = "test.concurrent()" },
        .{ .source = "test.concurrent.failing.only()", .reported = "only", .expected = "test.concurrent.failing()" },
        .{ .source = "test.only.each()()", .reported = "only", .expected = "test.each()()" },
        .{ .source = "fdescribe()", .reported = "fdescribe", .expected = "describe()" },
        .{ .source = "fit()", .reported = "fit", .expected = "it()" },
        .{ .source = "fit.each`table`()", .reported = "fit", .expected = "it.each`table`()" },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, "fixture.js", optionsOnly());
        defer result.deinit(std.testing.allocator);

        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
        const diagnostic = findDiagnostic(result).?;
        try std.testing.expectEqualStrings("Unexpected focused test", diagnostic.message);
        try std.testing.expectEqualStrings(case.reported, case.source[diagnostic.span.start..diagnostic.span.end]);
        try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        try std.testing.expectEqual(@as(usize, 1), diagnostic.suggestions.len);
        try std.testing.expectEqualStrings("Remove focus from test", diagnostic.suggestions[0].message);
        try std.testing.expectEqual(@as(usize, 1), diagnostic.suggestions[0].fixes.len);

        const suggested = try applySuggestion(std.testing.allocator, case.source, diagnostic.suggestions[0]);
        defer std.testing.allocator.free(suggested);
        try std.testing.expectEqualStrings(case.expected, suggested);
    }
}

test "allows unfocused and indirect Jest calls" {
    const cases = [_][]const u8{
        "describe()",
        "it()",
        "describe.skip()",
        "it.skip()",
        "test()",
        "test.skip()",
        "const appliedOnly = describe.only; appliedOnly.apply(describe);",
        "const calledOnly = it.only; calledOnly.call(it);",
        "it.each()()",
        "it.each`table`()",
        "test.each()()",
        "test.each`table`()",
        "test.concurrent()",
        "function fit() {} fit();",
        "function describe() {} describe.only();",
    };

    for (cases) |source| {
        var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expect(!helpers.hasRule(result, rule_id));
    }
}

test "supports configured global aliases" {
    const source = "context.only('suite', () => {});";
    var options = optionsOnly();
    try std.testing.expect(options.jest_global_aliases.append("describe", "context"));

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));

    const diagnostic = findDiagnostic(result).?;
    const suggested = try applySuggestion(std.testing.allocator, source, diagnostic.suggestions[0]);
    defer std.testing.allocator.free(suggested);
    try std.testing.expectEqualStrings("context('suite', () => {});", suggested);

    var focused_options = optionsOnly();
    try std.testing.expect(focused_options.jest_global_aliases.append("fdescribe", "focusSuite"));
    var focused_result = try lint.lintSource(std.testing.allocator, "focusSuite();", "fixture.js", focused_options);
    defer focused_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(focused_result, rule_id));
    try std.testing.expectEqual(@as(usize, 0), focused_result.diagnostics[0].suggestions.len);
}

test "supports ESM aliases and withholds unsafe focused-name suggestions" {
    const source =
        \\import { describe as describeThis, fdescribe as describeJustThis } from "@jest/globals";
        \\describeThis.only();
        \\describeJustThis();
        \\describeJustThis.each()();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, rule_id));

    try std.testing.expectEqual(@as(usize, 1), result.diagnostics[0].suggestions.len);
    try std.testing.expectEqual(@as(usize, 0), result.diagnostics[1].suggestions.len);
    try std.testing.expectEqual(@as(usize, 0), result.diagnostics[2].suggestions.len);

    const valid_alias =
        \\import { describe as fdescribe } from "@jest/globals";
        \\fdescribe();
    ;
    var valid_result = try lint.lintSource(std.testing.allocator, valid_alias, "fixture.js", optionsOnly());
    defer valid_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(valid_result, rule_id));
}

test "supports destructured CommonJS Jest globals" {
    const source =
        \\const { describe: suite, fdescribe } = require("@jest/globals");
        \\suite.only();
        \\fdescribe();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, rule_id));
    try std.testing.expectEqual(@as(usize, 1), result.diagnostics[0].suggestions.len);
    try std.testing.expectEqual(@as(usize, 1), result.diagnostics[1].suggestions.len);

    const nested =
        \\function register() {
        \\  const { fdescribe } = require("@jest/globals");
        \\  fdescribe();
        \\}
    ;
    var nested_result = try lint.lintSource(std.testing.allocator, nested, "fixture.js", optionsOnly());
    defer nested_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(nested_result, rule_id));

    const shadowed =
        \\function load(require) {
        \\  const { fdescribe } = require("@jest/globals");
        \\  fdescribe();
        \\}
    ;
    var shadowed_result = try lint.lintSource(std.testing.allocator, shadowed, "fixture.js", optionsOnly());
    defer shadowed_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(shadowed_result, rule_id));
}

test "supports JavaScript TypeScript JSX and TSX" {
    const cases = [_]struct { source: []const u8, file_name: []const u8 }{
        .{ .source = "test.only('js', () => {});", .file_name = "fixture.js" },
        .{ .source = "test.only('ts', (): void => {});", .file_name = "fixture.ts" },
        .{ .source = "test.only('jsx', () => <div />);", .file_name = "fixture.jsx" },
        .{ .source = "test.only('tsx', (): JSX.Element => <div />);", .file_name = "fixture.tsx" },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, case.file_name, optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    }
}

test "uses the recommended default and parses rule and alias configuration" {
    try std.testing.expect((lint.Options{}).jest_no_focused_tests);

    var options = lint.Options.allDisabled();
    try std.testing.expect(options.setByCliName(rule_id, true));
    try std.testing.expect(options.jest_no_focused_tests);

    var rule_config = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "\"error\"", .{});
    defer rule_config.deinit();
    options.jest_no_focused_tests = false;
    try options.setByRuleConfigValue(rule_id, rule_config.value);
    try std.testing.expect(options.jest_no_focused_tests);

    var aliases = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "{\"describe\":[\"context\"],\"test\":[\"specify\"]}",
        .{},
    );
    defer aliases.deinit();
    try options.setJestGlobalAliasesFromConfig(aliases.value);
    try std.testing.expectEqualStrings("describe", options.jest_global_aliases.canonicalFor("context").?);
    try std.testing.expectEqualStrings("test", options.jest_global_aliases.canonicalFor("specify").?);
}

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.jest_no_focused_tests = true;
    return options;
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id)) return diagnostic;
    }
    return null;
}

fn applySuggestion(allocator: std.mem.Allocator, source: []const u8, suggestion: lint.Suggestion) ![]u8 {
    const fix = suggestion.fixes[0];
    return std.mem.concat(allocator, u8, &.{
        source[0..fix.span.start],
        fix.replacement,
        source[fix.span.end..],
    });
}
