const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const rule_id = lint.rules.jest_no_mocks_import.id;
const expected_message = "Mocks should not be manually imported from a __mocks__ directory. Instead use `jest.mock` and import from the original module path";

test "reports ES imports from mock directories with useful locations" {
    const cases = [_][]const u8{
        "import thing from './__mocks__/index';",
        "import './nested/__mocks__/setup';",
        "import type { Mock } from '@scope/pkg/__mocks__/types';",
    };

    for (cases) |source| {
        var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
        const diagnostic = findDiagnostic(result).?;
        try std.testing.expectEqualStrings(expected_message, diagnostic.message);
        const reported = source[diagnostic.span.start..diagnostic.span.end];
        try std.testing.expect(std.mem.startsWith(u8, reported, "import"));
        try std.testing.expect(std.mem.indexOf(u8, reported, "__mocks__") != null);
    }
}

test "reports CommonJS requires and dynamic imports" {
    const source =
        \\require("./__mocks__");
        \\require("./nested/__mocks__/");
        \\require("__mocks__/index", extra);
        \\import("./__mocks__/dynamic");
        \\import(`./nested/__mocks__/template`);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, rule_id));
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, rule_id)) continue;
        try std.testing.expectEqualStrings(expected_message, diagnostic.message);
        const reported = source[diagnostic.span.start..diagnostic.span.end];
        try std.testing.expect(reported[0] == '"' or reported[0] == '`');
        try std.testing.expect(std.mem.indexOf(u8, reported, "__mocks__") != null);
    }
}

test "reports Windows-style CommonJS mock paths" {
    const invalid = "require('.\\\\nested\\\\__mocks__\\\\user');";
    var invalid_result = try lint.lintSource(std.testing.allocator, invalid, "fixture.js", optionsOnly());
    defer invalid_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(invalid_result, rule_id));

    const valid = "require('.\\\\nested\\\\__mocks__.js');";
    var valid_result = try lint.lintSource(std.testing.allocator, valid, "fixture.js", optionsOnly());
    defer valid_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(valid_result, rule_id));
}

test "allows similarly named paths and non-static module references" {
    const source =
        \\import something from "something";
        \\require("./__mocks__.js");
        \\require("./__mocks__x");
        \\require("./__mocks__x/x");
        \\require("./x__mocks__");
        \\require("./x__mocks__/x");
        \\require();
        \\const path = "./__mocks__/index";
        \\require(path);
        \\import(path);
        \\import(`./${directory}/__mocks__/index`);
        \\entirelyDifferent("./__mocks__/index");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, rule_id));
}

test "matches upstream handling of shadowed require calls" {
    const source = "function load(require) { return require('./__mocks__/index'); }";
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
}

test "supports JavaScript TypeScript JSX and TSX" {
    const cases = [_]struct { source: []const u8, file_name: []const u8 }{
        .{ .source = "require('./__mocks__/js');", .file_name = "fixture.js" },
        .{ .source = "import type { Mock } from './__mocks__/ts';", .file_name = "fixture.ts" },
        .{ .source = "const node = <div />; import('./__mocks__/jsx');", .file_name = "fixture.jsx" },
        .{ .source = "const node: JSX.Element = <div />; import('./__mocks__/tsx');", .file_name = "fixture.tsx" },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, case.file_name, optionsOnly());
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, rule_id));
    }
}

test "uses the recommended default and accepts rule configuration" {
    try std.testing.expect((lint.Options{}).jest_no_mocks_import);

    var options = lint.Options.allDisabled();
    try std.testing.expect(options.setByCliName(rule_id, true));
    try std.testing.expect(options.jest_no_mocks_import);

    var config = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "\"error\"", .{});
    defer config.deinit();
    options.jest_no_mocks_import = false;
    try options.setByRuleConfigValue(rule_id, config.value);
    try std.testing.expect(options.jest_no_mocks_import);
}

fn optionsOnly() lint.Options {
    var options = lint.Options.allDisabled();
    options.jest_no_mocks_import = true;
    return options;
}

fn findDiagnostic(result: lint.Result) ?lint.Diagnostic {
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, rule_id)) return diagnostic;
    }
    return null;
}
