const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-restricted-modules for restricted require sources" {
    const source =
        \\const fs = require("fs");
        \\const path = (require)("path");
        \\const ok = require("ok");
    ;

    const options = try optionsWithConfig("[\"error\", \"fs\", \"path\"]");
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_restricted_modules.id));
}

test "reports object path restrictions with custom messages" {
    const source =
        \\const fs = require("fs");
        \\const path = require("path");
    ;

    const options = try optionsWithConfig(
        "[\"error\", {\"name\":\"fs\", \"message\":\"Use graceful-fs instead.\"}]",
    );
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_restricted_modules.id));
    try std.testing.expect(hasMessage(result, "Use graceful-fs instead."));
}

test "reports patterns and honors negated patterns" {
    const source =
        \\const privateApi = require("private/api");
        \\const allowed = require("private/allowed");
        \\const nested = require("secret/nested/value");
    ;

    const options = try optionsWithConfig(
        "[\"error\", {\"patterns\":[\"private/*\", \"!private/allowed\", \"secret/*\"]}]",
    );
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_restricted_modules.id));
}

test "ignores dynamic require arguments and non-require calls" {
    const source =
        \\const fs = customRequire("fs");
        \\const dynamic = require(name);
        \\const templated = require(`pkg-${name}`);
        \\const staticTemplate = require(`fs`);
    ;

    const options = try optionsWithConfig("[\"error\", \"fs\"]");
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_restricted_modules.id));
}

test "can disable no-restricted-modules" {
    const source =
        \\const fs = require("fs");
    ;

    var options = try optionsWithConfig("[\"error\", \"fs\"]");
    options.no_restricted_modules = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_restricted_modules.id));
}

test "parses paths and patterns config" {
    const options = try optionsWithConfig(
        "[\"error\", {\"paths\":[{\"name\":\"fs\", \"message\":\"Use safe-fs.\"}], \"patterns\":[\"private/*\"]}]",
    );

    try std.testing.expect(options.no_restricted_modules);
    try std.testing.expectEqual(@as(usize, 2), options.no_restricted_modules_entries.count);
    try std.testing.expectEqualStrings("fs", options.no_restricted_modules_entries.at(0).source());
    try std.testing.expectEqualStrings("Use safe-fs.", options.no_restricted_modules_entries.at(0).message().?);
    try std.testing.expectEqualStrings("private/*", options.no_restricted_modules_entries.at(1).source());
}

fn optionsWithConfig(config: []const u8) !lint.Options {
    var options = baseOptions();
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, config, .{});
    defer parsed.deinit();
    try options.setByRuleConfigValue("no-restricted-modules", parsed.value);
    return options;
}

fn baseOptions() lint.Options {
    return .{
        .no_undef = false,
        .no_unassigned_vars = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_restricted_modules.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
