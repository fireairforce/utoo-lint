const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-restricted-imports for restricted modules" {
    const source =
        \\import fs from "fs";
        \\import "path";
        \\import ok from "ok";
    ;

    const options = try optionsWithConfig("[\"error\",\"fs\",\"path\"]");
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_restricted_imports.id));
}

test "reports restricted importNames with custom messages" {
    const source =
        \\import banned, { danger, safe as local } from "lib";
        \\import { other } from "lib";
    ;

    const options = try optionsWithConfig(
        "[\"error\",{\"paths\":[{\"name\":\"lib\",\"importNames\":[\"default\",\"danger\"],\"message\":\"Use safe-lib instead.\"}]}]",
    );
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_restricted_imports.id));
    try std.testing.expect(hasMessage(result, "Use safe-lib instead."));
}

test "reports imports outside allowImportNames" {
    const source =
        \\import { safe, danger } from "lib";
        \\import * as everything from "lib";
        \\import "lib";
    ;

    const options = try optionsWithConfig(
        "[\"error\",{\"paths\":[{\"name\":\"lib\",\"allowImportNames\":[\"safe\"]}]}]",
    );
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_restricted_imports.id));
}

test "reports simple pattern matches and re-exports" {
    const source =
        \\import thing from "@internal/thing";
        \\export { value } from "@internal/value";
        \\export * from "@internal/all";
        \\import ok from "@public/thing";
    ;

    const options = try optionsWithConfig("[\"error\",{\"patterns\":[\"@internal/*\"]}]");
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_restricted_imports.id));
}

test "allows type-only imports when configured" {
    const source =
        \\import type { T } from "types";
        \\export type { U } from "types";
        \\import { value } from "types";
    ;

    const options = try optionsWithConfig(
        "[\"error\",{\"paths\":[{\"name\":\"types\",\"allowTypeImports\":true}]}]",
    );
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_restricted_imports.id));
}

test "can disable no-restricted-imports" {
    const source =
        \\import fs from "fs";
    ;

    var options = try optionsWithConfig("[\"error\",\"fs\"]");
    options.no_restricted_imports = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_restricted_imports.id));
}

test "parses object pattern groups" {
    var options = try optionsWithConfig(
        "[\"error\",{\"patterns\":{\"group\":[\"private/*\",\"secret/*\"],\"importNames\":[\"leak\"],\"message\":\"Use public API.\"}}]",
    );

    try std.testing.expect(options.no_restricted_imports);
    try std.testing.expectEqual(@as(usize, 2), options.no_restricted_imports_entries.count);
    try std.testing.expectEqualStrings("private/*", options.no_restricted_imports_entries.at(0).source());
    try std.testing.expect(options.no_restricted_imports_entries.at(0).import_names.contains("leak"));
    try std.testing.expectEqualStrings("Use public API.", options.no_restricted_imports_entries.at(1).message().?);
}

fn optionsWithConfig(config: []const u8) !lint.Options {
    var options = baseOptions();
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, config, .{});
    defer parsed.deinit();
    try options.setByRuleConfigValue("no-restricted-imports", parsed.value);
    return options;
}

fn baseOptions() lint.Options {
    return .{
        .import_no_unresolved = false,
        .no_empty_block_statements = false,
        .no_undef = false,
        .no_unassigned_vars = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_restricted_imports.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
