const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports ascending sort-keys violations" {
    const source =
        \\const value = {
        \\  zebra: 1,
        \\  alpha: 2,
        \\  beta: 3,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.sort_keys.id));
}

test "supports descending order" {
    const source =
        \\const value = {
        \\  alpha: 1,
        \\  zebra: 2,
        \\};
    ;

    var options = optionsOnly();
    options.sort_keys_order = .desc;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.sort_keys.id));
}

test "supports case insensitive sort-keys" {
    const source =
        \\const value = {
        \\  alpha: 1,
        \\  Beta: 2,
        \\};
    ;

    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer default_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(default_result, lint.rules.sort_keys.id));

    var options = optionsOnly();
    options.sort_keys_case_sensitive = false;
    var ignored_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer ignored_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(ignored_result, lint.rules.sort_keys.id));
}

test "supports natural sort-keys" {
    const source =
        \\const value = {
        \\  item2: 1,
        \\  item10: 2,
        \\};
    ;

    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer default_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(default_result, lint.rules.sort_keys.id));

    var options = optionsOnly();
    options.sort_keys_natural = true;
    var natural_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer natural_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(natural_result, lint.rules.sort_keys.id));
}

test "supports minKeys" {
    const source =
        \\const small = { b: 1, a: 2 };
        \\const large = { c: 1, b: 2, a: 3 };
    ;

    var options = optionsOnly();
    options.sort_keys_min_keys = 3;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.sort_keys.id));
}

test "supports allowLineSeparatedGroups" {
    const source =
        \\const value = {
        \\  zebra: 1,
        \\
        \\  alpha: 2,
        \\};
    ;

    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer default_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(default_result, lint.rules.sort_keys.id));

    var options = optionsOnly();
    options.sort_keys_allow_line_separated_groups = true;
    var grouped_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer grouped_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(grouped_result, lint.rules.sort_keys.id));
}

test "skips dynamic keys and spreads as group boundaries" {
    const source =
        \\const value = {
        \\  z: 1,
        \\  [dynamic]: 2,
        \\  a: 3,
        \\  ...extra,
        \\  c: 4,
        \\  b: 5,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", optionsOnly());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.sort_keys.id));
}

test "parses sort-keys config" {
    const options = try optionsWithConfig(
        "[\"error\",\"desc\",{\"caseSensitive\":false,\"natural\":true,\"minKeys\":3,\"allowLineSeparatedGroups\":true}]",
    );

    try std.testing.expect(options.sort_keys);
    try std.testing.expect(options.sort_keys_order == .desc);
    try std.testing.expect(!options.sort_keys_case_sensitive);
    try std.testing.expect(options.sort_keys_natural);
    try std.testing.expectEqual(@as(usize, 3), options.sort_keys_min_keys);
    try std.testing.expect(options.sort_keys_allow_line_separated_groups);
}

test "can disable sort-keys" {
    const source =
        \\const value = { b: 1, a: 2 };
    ;

    var options = optionsOnly();
    options.sort_keys = false;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.sort_keys.id));
}

fn optionsWithConfig(config: []const u8) !lint.Options {
    var options = baseOptions();
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, config, .{});
    defer parsed.deinit();
    try options.setByRuleConfigValue("sort-keys", parsed.value);
    return options;
}

fn optionsOnly() lint.Options {
    var options = baseOptions();
    options.sort_keys = true;
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
