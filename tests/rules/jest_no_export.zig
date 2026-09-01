const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const rule_id = lint.rules.jest_no_export.id;

test "reports ESM and type-only exports with useful locations" {
    const source =
        \\const local = 1;
        \\type Shape = { value: number };
        \\export const helper = local;
        \\export default function factory() { return helper; }
        \\export type PublicShape = Shape;
        \\export { type Shape };
        \\test("works", () => expect(helper).toBe(1));
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, rule_id));
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, rule_id)) continue;
        try std.testing.expectEqualStrings("Do not export from a test file", diagnostic.message);
        try std.testing.expect(std.mem.startsWith(u8, source[diagnostic.span.start..diagnostic.span.end], "export"));
        try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
    }
}

test "reports supported CommonJS export forms" {
    const source =
        \\module.exports = value;
        \\module.exports.named = value;
        \\module.exports.exports.named = value;
        \\module.export.named = value;
        \\module["exports"] = value;
        \\module["exports"].named = value;
        \\module["export"] = value;
        \\module[`exports`] = value;
        \\exports.named = value;
        \\exports.export["named"] = value;
        \\it("works", () => {});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 10), helpers.countRule(result, rule_id));
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, rule_id)) continue;
        const reported = source[diagnostic.span.start..diagnostic.span.end];
        try std.testing.expect(std.mem.startsWith(u8, reported, "module") or std.mem.startsWith(u8, reported, "exports"));
        try std.testing.expect(!std.mem.endsWith(u8, reported, ";"));
    }
}

test "reports TypeScript export assignments" {
    const source =
        \\const value = {};
        \\export = value;
        \\describe("suite", () => {});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    const diagnostic = findDiagnostic(result).?;
    try std.testing.expectEqualStrings("export = value;", source[diagnostic.span.start..diagnostic.span.end]);
}

test "allows exports in files without tests and unrelated assignments" {
    const cases = [_]struct { source: []const u8, file_name: []const u8 }{
        .{ .source = "export const helper = 1; module.exports = helper;", .file_name = "fixture.js" },
        .{ .source = "module.other = value; test('works', () => {});", .file_name = "fixture.js" },
        .{ .source = "module[name] = value; test('works', () => {});", .file_name = "fixture.js" },
        .{ .source = "module[`${variable}`] = value; test('works', () => {});", .file_name = "fixture.js" },
        .{ .source = "module[`${\"exports\"}`] = value; test('works', () => {});", .file_name = "fixture.js" },
        .{ .source = "const module = localModule; module.exports = value; test('works', () => {});", .file_name = "fixture.js" },
        .{ .source = "const exports = {}; exports.named = value; test('works', () => {});", .file_name = "fixture.js" },
        .{ .source = "function test() {} export const helper = 1; test();", .file_name = "fixture.js" },
        .{ .source = "import type { test } from '@jest/globals'; export const helper = 1;", .file_name = "fixture.ts" },
        .{ .source = "window.module.exports = value; it('works', () => {});", .file_name = "fixture.js" },
        .{ .source = "export const helper = 1; test.each();", .file_name = "fixture.js" },
        .{ .source = "export const helper = 1; describe.concurrent('not Jest', () => {});", .file_name = "fixture.js" },
        .{ .source = "export const helper = 1; test().only('not Jest', () => {});", .file_name = "fixture.js" },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, case.file_name, optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expect(!helpers.hasRule(result, rule_id));
    }
}

test "supports aliased @jest/globals imports and Jest call chains" {
    const source =
        \\import { describe as suite, test as check } from "@jest/globals";
        \\export const helper = 1;
        \\check.concurrent.each([[1]])("case", () => {});
        \\suite.skip("suite", () => {});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));

    const tagged_source =
        \\export const helper = 1;
        \\it.each`value`("case", () => {});
    ;
    var tagged_result = try lint.lintSource(std.testing.allocator, tagged_source, "fixture.js", optionsOnly());
    defer tagged_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(tagged_result, rule_id));
}

test "supports JavaScript TypeScript JSX and TSX" {
    const cases = [_]struct { source: []const u8, file_name: []const u8 }{
        .{ .source = "export const helper = 1; test('js', () => {});", .file_name = "fixture.js" },
        .{ .source = "export const helper: number = 1; test('ts', () => {});", .file_name = "fixture.ts" },
        .{ .source = "export const helper = <div />; test('jsx', () => {});", .file_name = "fixture.jsx" },
        .{ .source = "export const helper: JSX.Element = <div />; test('tsx', () => {});", .file_name = "fixture.tsx" },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, case.file_name, optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    }
}

test "uses the recommended default and parses rule configuration" {
    try std.testing.expect((lint.Options{}).jest_no_export);

    var options = lint.Options.allDisabled();
    try std.testing.expect(options.setByCliName(rule_id, true));
    try std.testing.expect(options.jest_no_export);

    var config = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "[\"warn\"]", .{});
    defer config.deinit();
    options.jest_no_export = false;
    try options.setByRuleConfigValue(rule_id, config.value);
    try std.testing.expect(options.jest_no_export);

    options.jest_no_export = false;
    var result = try lint.lintSource(
        std.testing.allocator,
        "export const helper = 1; test('disabled', () => {});",
        "fixture.js",
        options,
    );
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, rule_id));
}

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.jest_no_export = true;
    return options;
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id)) return diagnostic;
    }
    return null;
}
