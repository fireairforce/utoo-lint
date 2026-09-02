const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const rule_id = lint.rules.jest_valid_describe_callback.id;

test "reports missing and non-function callbacks with useful locations" {
    const cases = [_]struct {
        source: []const u8,
        message: []const u8,
        reported: []const u8,
    }{
        .{ .source = "describe()", .message = "Describe requires name and callback arguments", .reported = "describe()" },
        .{ .source = "describe.each()()", .message = "Describe requires name and callback arguments", .reported = "describe.each()()" },
        .{ .source = "describe('name')", .message = "Describe requires name and callback arguments", .reported = "'name'" },
        .{ .source = "describe(() => {})", .message = "Describe requires name and callback arguments", .reported = "() => {}" },
        .{ .source = "describe('name', value)", .message = "Second argument must be function", .reported = "'name', value" },
        .{ .source = "describe('name', call())", .message = "Second argument must be function", .reported = "'name', call()" },
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

test "reports async callbacks for describe aliases" {
    const source =
        \\describe('one', async () => {});
        \\fdescribe('two', async function () {});
        \\xdescribe('three', async function () {});
        \\describe.only('four', async () => {});
        \\describe.skip('five', async () => {});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, rule_id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id)) {
            try std.testing.expectEqualStrings("No async describe callback", diagnostic.message);
        }
    }
}

test "rejects parameters except for describe each callbacks" {
    const invalid =
        \\describe('arrow', done => {});
        \\describe('function', function (one, two, three) {});
        \\describe('rest', (...values) => {});
    ;
    var invalid_result = try lint.lintSource(std.testing.allocator, invalid, "fixture.js", optionsOnly());
    defer invalid_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(invalid_result, rule_id));
    try std.testing.expectEqualStrings("done", diagnosticSource(invalid, invalid_result.diagnostics[0]));
    try std.testing.expectEqualStrings("one, two, three", diagnosticSource(invalid, invalid_result.diagnostics[1]));
    try std.testing.expectEqualStrings("...values", diagnosticSource(invalid, invalid_result.diagnostics[2]));

    const valid =
        \\describe.each([1, 2])('%s', (one, two) => {});
        \\describe['each']([1, 2])('%s', value => {});
        \\describe.each`value\n${1}`('%s', ({ value }) => {});
    ;
    var valid_result = try lint.lintSource(std.testing.allocator, valid, "fixture.js", optionsOnly());
    defer valid_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(valid_result, rule_id));
}

test "reports returned values without entering nested functions" {
    const source =
        \\describe('direct', () => { return Promise.resolve(); });
        \\describe('conditional', () => { if (ready) return value; });
        \\describe('concise call', () => test('works', () => {}));
        \\describe('concise value', () => 42);
        \\describe('nested helpers', () => {
        \\  function helper() { return 1; }
        \\  const arrow = () => { return 2; };
        \\  test('works', () => { return Promise.resolve(); });
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, rule_id));
    try std.testing.expectEqualStrings("return Promise.resolve();", diagnosticSource(source, result.diagnostics[0]));
    try std.testing.expectEqualStrings("return value;", diagnosticSource(source, result.diagnostics[1]));
    try std.testing.expectEqualStrings("() => test('works', () => {})", diagnosticSource(source, result.diagnostics[2]));
    try std.testing.expectEqualStrings("() => 42", diagnosticSource(source, result.diagnostics[3]));
}

test "reports every independent callback problem" {
    const source = "describe('name', async function (done) { return value; });";
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, rule_id));
    try std.testing.expectEqualStrings("No async describe callback", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("Unexpected argument(s) in describe callback", result.diagnostics[1].message);
    try std.testing.expectEqualStrings("Unexpected return statement in describe callback", result.diagnostics[2].message);
}

test "supports imported required and configured aliases while ignoring shadows" {
    const imported =
        \\import { describe as suite, fdescribe, xdescribe } from '@jest/globals';
        \\suite('one', async () => {});
        \\fdescribe('two', done => {});
        \\xdescribe('three', () => value);
    ;
    var imported_result = try lint.lintSource(std.testing.allocator, imported, "fixture.js", optionsOnly());
    defer imported_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(imported_result, rule_id));

    const required =
        \\const { describe: suite } = require('@jest/globals');
        \\suite('name', async () => {});
    ;
    var required_result = try lint.lintSource(std.testing.allocator, required, "fixture.js", optionsOnly());
    defer required_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(required_result, rule_id));

    var alias_options = optionsOnly();
    try std.testing.expect(alias_options.jest_global_aliases.append("describe", "suite"));
    const aliases = "suite('name', async () => {});";
    var alias_result = try lint.lintSource(std.testing.allocator, aliases, "fixture.js", alias_options);
    defer alias_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(alias_result, rule_id));

    const shadowed = "function run(describe) { describe('name', async () => {}); }";
    var shadowed_result = try lint.lintSource(std.testing.allocator, shadowed, "fixture.js", optionsOnly());
    defer shadowed_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(shadowed_result, rule_id));
}

test "accepts valid synchronous zero-argument callbacks" {
    const source =
        \\describe('arrow', () => {});
        \\describe('function', function () {});
        \\fdescribe('focused', () => { test('works', async () => {}); });
        \\xdescribe('skipped', function* () { yield value; });
        \\describe('nested return', () => { test('works', () => { return value; }); });
        \\describe('extra argument', () => {}, timeout);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, rule_id));
}

test "supports JavaScript TypeScript JSX and TSX" {
    const cases = [_]struct { source: []const u8, file_name: []const u8 }{
        .{ .source = "describe('js', async () => {});", .file_name = "fixture.js" },
        .{ .source = "describe('ts', async (): Promise<void> => {});", .file_name = "fixture.ts" },
        .{ .source = "describe('jsx', async () => { <div />; });", .file_name = "fixture.jsx" },
        .{ .source = "describe('tsx', async (): Promise<void> => { <div />; });", .file_name = "fixture.tsx" },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, case.file_name, optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    }
}

test "uses the recommended default and accepts rule configuration" {
    try std.testing.expect((lint.Options{}).jest_valid_describe_callback);

    var options = lint.Options.allDisabled();
    try std.testing.expect(options.setByCliName(rule_id, true));
    try std.testing.expect(options.jest_valid_describe_callback);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "[\"error\"]", .{});
    defer parsed.deinit();
    try options.setByRuleConfigValue(rule_id, parsed.value);
    try std.testing.expect(options.jest_valid_describe_callback);
}

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.jest_valid_describe_callback = true;
    return options;
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id)) return diagnostic;
    }
    return null;
}

fn diagnosticSource(source: []const u8, diagnostic: lint.Diagnostic) []const u8 {
    return source[diagnostic.span.start..diagnostic.span.end];
}
