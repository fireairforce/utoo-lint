const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports id-denylist for restricted identifiers" {
    const source =
        \\const bad = 1;
        \\function run(bad) {
        \\  return bad;
        \\}
    ;

    const options = try optionsWithNames(
        \\["error", "bad"]
    );

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.id_denylist.id));
    try std.testing.expect(hasMessage(result, "Identifier 'bad' is restricted."));
}

test "allows read-only member properties but reports property writes" {
    const source =
        \\const obj = {};
        \\obj.bad;
        \\obj.bad = 1;
    ;

    const options = try optionsWithNames(
        \\["error", "bad"]
    );

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.id_denylist.id));
}

test "skips renamed imports, re-exports, and destructuring property keys" {
    const source =
        \\import { bad as renamed } from "pkg";
        \\export { bad as renamedAgain } from "pkg";
        \\const { bad: local } = source;
        \\renamed;
        \\renamedAgain;
        \\local;
    ;

    const options = try optionsWithNames(
        \\["error", "bad"]
    );

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.id_denylist.id));
}

test "reports private identifiers" {
    const source =
        \\class Example {
        \\  #bad;
        \\}
    ;

    const options = try optionsWithNames(
        \\["error", "bad"]
    );

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.id_denylist.id));
    try std.testing.expect(hasMessage(result, "Identifier '#bad' is restricted."));
}

test "can disable id-denylist" {
    const source =
        \\const bad = 1;
    ;

    var options = try optionsWithNames(
        \\["error", "bad"]
    );
    options.id_denylist = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.id_denylist.id));
}

fn optionsWithNames(config: []const u8) !lint.Options {
    var options = baseOptions();
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, config, .{});
    defer parsed.deinit();
    try options.setByRuleConfigValue("id-denylist", parsed.value);
    return options;
}

fn baseOptions() lint.Options {
    return .{
        .import_no_unresolved = false,
        .max_classes_per_file = false,
        .max_statements = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_private_class_members = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .typescript_eslint_no_empty_function = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.id_denylist.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
