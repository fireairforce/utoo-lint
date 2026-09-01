const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const rule_id = lint.rules.jest_no_interpolation_in_snapshots.id;

test "reports interpolated inline snapshots with useful locations" {
    const cases = [_][]const u8{
        "expect(value).toMatchInlineSnapshot(`${interpolated}`);",
        "expect(value).not.toMatchInlineSnapshot(`${interpolated}`);",
        "expect(value).toMatchInlineSnapshot({}, `${interpolated}`);",
        "expect(value).not.toMatchInlineSnapshot({}, `${interpolated}`);",
        "expect(value).toThrowErrorMatchingInlineSnapshot(`${interpolated}`);",
        "expect(value).rejects.not.toThrowErrorMatchingInlineSnapshot(`${interpolated}`);",
    };

    for (cases) |source| {
        var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
        const diagnostic = findDiagnostic(result).?;
        try std.testing.expectEqualStrings("Do not use string interpolation inside of snapshots", diagnostic.message);
        try std.testing.expectEqualStrings("`${interpolated}`", source[diagnostic.span.start..diagnostic.span.end]);
    }
}

test "checks every snapshot argument and allows static and escaped templates" {
    const invalid = "expect(value).toMatchInlineSnapshot(`${first}`, `${second}`);";
    var invalid_result = try lint.lintSource(std.testing.allocator, invalid, "fixture.js", optionsOnly());
    defer invalid_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(invalid_result, rule_id));

    const valid_cases = [_][]const u8{
        "expect(value).toMatchInlineSnapshot();",
        "expect(value).toMatchInlineSnapshot(`No interpolation`);",
        "expect(value).toMatchInlineSnapshot({}, `No interpolation`);",
        "expect(value).toMatchInlineSnapshot(`\\${escaped}`);",
        "expect(value).toThrowErrorMatchingInlineSnapshot(`No interpolation`);",
    };
    for (valid_cases) |source| {
        var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expect(!helpers.hasRule(result, rule_id));
    }
}

test "ignores non-snapshot templates and shadowed APIs" {
    const cases = [_][]const u8{
        "expect(value).toEqual(`${interpolated}`);",
        "myObjectWants.toMatchInlineSnapshot({}, `${interpolated}`);",
        "toMatchInlineSnapshot({}, `${interpolated}`);",
        "function expect() {} expect(value).toMatchInlineSnapshot(`${interpolated}`);",
        "const expect = makeExpect(); expect(value).toMatchInlineSnapshot(`${interpolated}`);",
    };

    for (cases) |source| {
        var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expect(!helpers.hasRule(result, rule_id));
    }
}

test "supports imported and configured expect aliases" {
    const imported_source =
        \\import { expect as check } from "@jest/globals";
        \\check(value).toMatchInlineSnapshot(`${interpolated}`);
    ;
    var imported_result = try lint.lintSource(std.testing.allocator, imported_source, "fixture.js", optionsOnly());
    defer imported_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(imported_result, rule_id));

    var options = optionsOnly();
    try std.testing.expect(options.jest_global_aliases.append("expect", "check"));
    var alias_result = try lint.lintSource(
        std.testing.allocator,
        "check(value).toMatchInlineSnapshot(`${interpolated}`);",
        "fixture.js",
        options,
    );
    defer alias_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(alias_result, rule_id));
}

test "supports JavaScript TypeScript JSX and TSX" {
    const cases = [_]struct { source: []const u8, file_name: []const u8 }{
        .{ .source = "expect(value).toMatchInlineSnapshot(`${js}`);", .file_name = "fixture.js" },
        .{ .source = "expect(value as string).toMatchInlineSnapshot(`${ts}`);", .file_name = "fixture.ts" },
        .{ .source = "expect(<div />).toMatchInlineSnapshot(`${jsx}`);", .file_name = "fixture.jsx" },
        .{ .source = "expect(<div /> as JSX.Element).toMatchInlineSnapshot(`${tsx}`);", .file_name = "fixture.tsx" },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, case.file_name, optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    }
}

test "uses the recommended default and accepts rule configuration" {
    try std.testing.expect((lint.Options{}).jest_no_interpolation_in_snapshots);

    var options = lint.Options.allDisabled();
    try std.testing.expect(options.setByCliName(rule_id, true));
    try std.testing.expect(options.jest_no_interpolation_in_snapshots);

    var config = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "\"error\"", .{});
    defer config.deinit();
    options.jest_no_interpolation_in_snapshots = false;
    try options.setByRuleConfigValue(rule_id, config.value);
    try std.testing.expect(options.jest_no_interpolation_in_snapshots);
}

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.jest_no_interpolation_in_snapshots = true;
    return options;
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id)) return diagnostic;
    }
    return null;
}
