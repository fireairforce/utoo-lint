const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const rule_id = lint.rules.jest_no_jasmine_globals.id;

test "reports Jasmine global calls with useful locations" {
    const cases = [_]struct {
        source: []const u8,
        message: []const u8,
    }{
        .{ .source = "spyOn(object, 'method');", .message = "Illegal usage of global `spyOn`, prefer `jest.spyOn`" },
        .{ .source = "spyOnProperty(object, 'property');", .message = "Illegal usage of global `spyOnProperty`, prefer `jest.spyOn`" },
        .{ .source = "fail('reason');", .message = "Illegal usage of `fail`, prefer throwing an error, or the `done.fail` callback" },
        .{ .source = "pending('reason');", .message = "Illegal usage of `pending`, prefer explicitly skipping a test using `test.skip`" },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, "fixture.js", optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
        const diagnostic = findDiagnostic(result).?;
        try std.testing.expectEqualStrings(case.message, diagnostic.message);
        try std.testing.expectEqualStrings(case.source[0 .. case.source.len - 1], case.source[diagnostic.span.start..diagnostic.span.end]);
        try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
    }
}

test "allows Jest APIs and shadowed Jasmine globals" {
    const source =
        \\jest.spyOn(object, 'method');
        \\jest.fn();
        \\expect.extend({});
        \\expect.any(String);
        \\function run(spyOn, spyOnProperty, fail, pending) {
        \\  spyOn(); spyOnProperty(); fail(); pending();
        \\}
        \\const fail = () => {};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, rule_id));
}

test "reports Jasmine methods and applies upstream matcher autofixes" {
    const source =
        \\jasmine.any(String);
        \\jasmine['anything']();
        \\jasmine.arrayContaining([]);
        \\jasmine.objectContaining({});
        \\jasmine.stringMatching('value');
        \\jasmine.addMatchers({});
        \\jasmine.createSpy('name');
    ;
    const expected =
        \\expect.any(String);
        \\expect['anything']();
        \\expect.arrayContaining([]);
        \\expect.objectContaining({});
        \\expect.stringMatching('value');
        \\jasmine.addMatchers({});
        \\jasmine.createSpy('name');
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, rule_id));
    try std.testing.expectEqualStrings("Illegal usage of `jasmine.any`, prefer `expect.any`", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("Illegal usage of `jasmine.addMatchers`, prefer `expect.extend`", result.diagnostics[5].message);
    try std.testing.expectEqualStrings("Illegal usage of `jasmine.createSpy`, prefer `jest.fn`", result.diagnostics[6].message);
    for (result.diagnostics[0..5]) |diagnostic| {
        try std.testing.expectEqual(@as(usize, 1), diagnostic.fixes.len);
    }
    try std.testing.expectEqual(@as(usize, 0), result.diagnostics[5].fixes.len);
    try std.testing.expectEqual(@as(usize, 0), result.diagnostics[6].fixes.len);

    var fixed = try lint.applyFixes(std.testing.allocator, source, result.diagnostics);
    defer fixed.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(expected, fixed.output);
}

test "reports unsupported Jasmine members and assignments" {
    const source =
        \\jasmine.getEnv();
        \\jasmine.empty();
        \\jasmine.clock();
        \\jasmine.MAX_PRETTY_PRINT_ARRAY_LENGTH = 42;
        \\matcher = jasmine.truthy;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, rule_id));
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, rule_id)) continue;
        try std.testing.expectEqualStrings("Illegal usage of jasmine global", diagnostic.message);
        try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
    }
}

test "fixes literal Jasmine timeout assignments but not dynamic values" {
    const source =
        \\jasmine.DEFAULT_TIMEOUT_INTERVAL = 5000;
        \\jasmine.DEFAULT_TIMEOUT_INTERVAL = timeout;
    ;
    const expected =
        \\jest.setTimeout(5000);
        \\jasmine.DEFAULT_TIMEOUT_INTERVAL = timeout;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, rule_id));
    try std.testing.expectEqual(@as(usize, 1), result.diagnostics[0].fixes.len);
    try std.testing.expectEqual(@as(usize, 0), result.diagnostics[1].fixes.len);
    try std.testing.expectEqualStrings(
        "jasmine.DEFAULT_TIMEOUT_INTERVAL",
        source[result.diagnostics[0].span.start..result.diagnostics[0].span.end],
    );

    var fixed = try lint.applyFixes(std.testing.allocator, source, result.diagnostics);
    defer fixed.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(expected, fixed.output);
}

test "matches upstream handling of a shadowed jasmine object" {
    const source =
        \\function run(jasmine) {
        \\  jasmine.any(String);
        \\  jasmine.DEFAULT_TIMEOUT_INTERVAL = 5000;
        \\}
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, rule_id));
}

test "supports JavaScript TypeScript JSX and TSX" {
    const cases = [_]struct { source: []const u8, file_name: []const u8 }{
        .{ .source = "jasmine.any(String);", .file_name = "fixture.js" },
        .{ .source = "jasmine.any(String as StringConstructor);", .file_name = "fixture.ts" },
        .{ .source = "const node = <div />; jasmine.any(String);", .file_name = "fixture.jsx" },
        .{ .source = "const node: JSX.Element = <div />; jasmine.any(String);", .file_name = "fixture.tsx" },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, case.file_name, optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    }
}

test "uses the recommended default and accepts rule configuration" {
    try std.testing.expect((lint.Options{}).jest_no_jasmine_globals);

    var options = lint.Options.allDisabled();
    try std.testing.expect(options.setByCliName(rule_id, true));
    try std.testing.expect(options.jest_no_jasmine_globals);

    var config = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "\"error\"", .{});
    defer config.deinit();
    options.jest_no_jasmine_globals = false;
    try options.setByRuleConfigValue(rule_id, config.value);
    try std.testing.expect(options.jest_no_jasmine_globals);
}

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.jest_no_jasmine_globals = true;
    return options;
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id)) return diagnostic;
    }
    return null;
}
