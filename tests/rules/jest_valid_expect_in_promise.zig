const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const rule_id = lint.rules.jest_valid_expect_in_promise.id;
const expected_message = "This promise should either be returned or awaited to ensure the expects in its chain are called";

test "reports floating then catch and finally chains with useful locations" {
    const source =
        \\it('then', () => {
        \\  load().then(value => expect(value).toBeDefined());
        \\});
        \\test('catch', () => {
        \\  load().catch(error => expect(error).toBeDefined());
        \\});
        \\fit('finally', () => {
        \\  load().finally(() => expect(cleaned).toBe(true));
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, rule_id));

    const expected = [_][]const u8{
        "load().then(value => expect(value).toBeDefined())",
        "load().catch(error => expect(error).toBeDefined())",
        "load().finally(() => expect(cleaned).toBe(true))",
    };
    var offset: usize = 0;
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, rule_id)) continue;
        try std.testing.expectEqualStrings(expected_message, diagnostic.message);
        try std.testing.expectEqualStrings(expected[offset], source[diagnostic.span.start..diagnostic.span.end]);
        offset += 1;
    }
}

test "allows directly returned awaited and implicitly returned promise chains" {
    const source =
        \\it('returned', () => {
        \\  return load().then(value => expect(value).toBeDefined());
        \\});
        \\it('awaited', async () => {
        \\  await load().catch(error => expect(error).toBeDefined());
        \\});
        \\it('implicit', () => load().finally(() => expect(cleaned).toBe(true)));
        \\it('wrapped', async () => {
        \\  expect(await load().then(value => expect(value).toBeDefined())).toBeTruthy();
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, rule_id));
}

test "tracks assigned promises consumed later by supported patterns" {
    const source =
        \\it('consumes promises', async () => {
        \\  const awaited = load().then(value => expect(value).toBeDefined());
        \\  await awaited;
        \\  const returned = load().catch(error => expect(error).toBeDefined());
        \\  return Promise.all([returned]);
        \\});
        \\it('all settled', () => {
        \\  const promise = load().then(value => expect(value).toBeDefined());
        \\  return Promise.allSettled([promise]);
        \\});
        \\it('resolved', () => {
        \\  const promise = load().then(value => expect(value).toBeDefined());
        \\  return Promise.resolve(promise);
        \\});
        \\it('rejected', async () => {
        \\  const promise = load().then(value => expect(value).toBeDefined());
        \\  await Promise.reject(promise);
        \\});
        \\it('matcher', () => {
        \\  const promise = load().then(value => expect(value).toBeDefined());
        \\  expect(promise).resolves.toBeDefined();
        \\});
        \\it('nested await', async () => {
        \\  const promise = load().then(value => expect(value).toBeDefined());
        \\  log([[await promise]]);
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, rule_id));
}

test "reports unused mismatched and invalidated assigned promises" {
    const source =
        \\it('unused', async () => {
        \\  const unused = load().then(value => expect(value).toBeDefined());
        \\  const wrongMatcher = load().then(value => expect(value).toBeDefined());
        \\  expect(other).resolves.toBeDefined();
        \\  let reassigned = load().then(value => expect(value).toBeDefined());
        \\  reassigned = null;
        \\  await reassigned;
        \\  const unsupported = load().then(value => expect(value).toBeDefined());
        \\  return Promise.any([unsupported]);
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, rule_id));
}

test "allows promise-preserving reassignment before consumption" {
    const source =
        \\it('chains', async () => {
        \\  let promise = load().then(value => expect(value).toBeDefined());
        \\  promise = promise.then(value => expect(value).toBeDefined());
        \\  await promise;
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, rule_id));
}

test "limits checks to direct test callbacks and bails out for done callbacks" {
    const source =
        \\Promise.resolve().then(() => expect(true).toBe(true));
        \\const helper = () => Promise.resolve().then(() => expect(true).toBe(true));
        \\it('nested helper', () => {
        \\  run(() => Promise.resolve().then(() => expect(true).toBe(true)));
        \\});
        \\it('done', done => {
        \\  Promise.resolve().then(() => { expect(true).toBe(true); done(); });
        \\});
        \\it('without expect', () => {
        \\  Promise.resolve().then(() => work());
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, rule_id));
}

test "supports imported required and configured Jest APIs while ignoring shadowed expect" {
    const imported =
        \\import { expect as check, it as spec } from '@jest/globals';
        \\const { test: verify } = require('@jest/globals');
        \\spec('imported', () => { Promise.resolve().then(() => check(true).toBe(true)); });
        \\verify('required', () => { Promise.resolve().then(() => check(true).toBe(true)); });
    ;
    var imported_result = try lint.lintSource(std.testing.allocator, imported, "fixture.js", optionsOnly());
    defer imported_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(imported_result, rule_id));

    var alias_options = optionsOnly();
    try std.testing.expect(alias_options.jest_global_aliases.append("test", "spec"));
    try std.testing.expect(alias_options.jest_global_aliases.append("expect", "check"));
    const alias_source = "spec('alias', () => { Promise.resolve().then(() => check(true).toBe(true)); });";
    var alias_result = try lint.lintSource(std.testing.allocator, alias_source, "fixture.js", alias_options);
    defer alias_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(alias_result, rule_id));

    const shadowed = "it('shadowed', () => { const expect = verify; Promise.resolve().then(() => expect(true)); });";
    var shadowed_result = try lint.lintSource(std.testing.allocator, shadowed, "fixture.js", optionsOnly());
    defer shadowed_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(shadowed_result, rule_id));
}

test "supports JavaScript TypeScript JSX and TSX test files" {
    const cases = [_]struct { source: []const u8, file_name: []const u8 }{
        .{ .source = "it('js', () => { load().then(value => expect(value).toBe(true)); });", .file_name = "fixture.js" },
        .{ .source = "it('ts', () => { load().then((value: boolean) => expect(value).toBe(true)); });", .file_name = "fixture.ts" },
        .{ .source = "it('jsx', () => { load().then(() => expect(<div />).toBeTruthy()); });", .file_name = "fixture.jsx" },
        .{ .source = "it('tsx', () => { load().then(() => expect(<div /> as JSX.Element).toBeTruthy()); });", .file_name = "fixture.tsx" },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, case.file_name, optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    }
}

test "uses the recommended default and accepts ESLint and CLI rule configuration" {
    try std.testing.expect((lint.Options{}).jest_valid_expect_in_promise);

    var options = lint.Options.allDisabled();
    try std.testing.expect(options.setByCliName(rule_id, true));
    try std.testing.expect(options.jest_valid_expect_in_promise);

    var config = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "[\"error\"]", .{});
    defer config.deinit();
    try options.setByRuleConfigValue(rule_id, config.value);
    try std.testing.expect(options.jest_valid_expect_in_promise);
}

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.jest_valid_expect_in_promise = true;
    return options;
}
