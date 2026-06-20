const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-restricted-globals for configured global references" {
    const source =
        \\event;
        \\fdescribe("suite", () => {});
        \\const local = 1;
        \\local;
    ;

    const options = try optionsWithConfig(
        "[\"error\",\"event\",{\"name\":\"fdescribe\",\"message\":\"Use describe instead.\"}]",
    );
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_restricted_globals.id));
    try std.testing.expect(hasMessage(result, "Use describe instead."));
}

test "ignores no-restricted-globals when references are locally declared" {
    const source =
        \\function run(event) {
        \\  const fdescribe = () => {};
        \\  event.target;
        \\  fdescribe();
        \\}
    ;

    const options = try optionsWithConfig("[\"error\",\"event\",\"fdescribe\"]");
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_restricted_globals.id));
}

test "reports no-restricted-globals global object property access" {
    const source =
        \\window.event;
        \\globalThis.event;
        \\self["event"];
        \\customGlobal.event;
        \\local.event;
        \\const local = {};
    ;

    const options = try optionsWithConfig(
        "[\"error\",{\"globals\":[\"event\"],\"checkGlobalObject\":true,\"globalObjects\":[\"customGlobal\"]}]",
    );
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_restricted_globals.id));
}

test "allows no-restricted-globals global object checks to be disabled" {
    const source =
        \\event;
        \\window.event;
    ;

    const options = try optionsWithConfig(
        "[\"error\",{\"globals\":[\"event\"],\"checkGlobalObject\":false}]",
    );
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_restricted_globals.id));
}

test "can disable no-restricted-globals" {
    const source =
        \\event;
    ;

    var options = try optionsWithConfig("[\"error\",\"event\"]");
    options.no_restricted_globals = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_restricted_globals.id));
}

fn optionsWithConfig(config: []const u8) !lint.Options {
    var options = baseOptions();
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, config, .{});
    defer parsed.deinit();
    try options.setByRuleConfigValue("no-restricted-globals", parsed.value);
    return options;
}

fn baseOptions() lint.Options {
    return .{
        .no_empty_block_statements = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_restricted_globals.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
