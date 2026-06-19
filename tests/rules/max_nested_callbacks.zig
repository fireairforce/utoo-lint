const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports max-nested-callbacks for deeply nested callback arguments" {
    const source =
        \\first(function () {
        \\  second(() => {
        \\    third(function () {
        \\      done();
        \\    });
        \\  });
        \\});
    ;

    var options = baseOptions();
    options.max_nested_callbacks_max = 2;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.max_nested_callbacks.id));
    try std.testing.expect(hasMessage(result, "Maximum allowed is 2."));
}

test "does not count IIFE callees as callbacks" {
    const source =
        \\(function () {
        \\  first(function () {
        \\    done();
        \\  });
        \\})();
    ;

    var options = baseOptions();
    options.max_nested_callbacks_max = 0;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.max_nested_callbacks.id));
}

test "pops max-nested-callbacks state for sibling callbacks" {
    const source =
        \\first(function () {
        \\  done();
        \\});
        \\second(() => {
        \\  done();
        \\});
    ;

    var options = baseOptions();
    options.max_nested_callbacks_max = 1;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.max_nested_callbacks.id));
}

test "supports configured max-nested-callbacks max and deprecated maximum" {
    const source =
        \\first(() => {
        \\  second(() => {
        \\    done();
        \\  });
        \\});
    ;

    const max_config =
        \\["error", { "max": 1 }]
    ;
    var max_options = baseOptions();
    var max_parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, max_config, .{});
    defer max_parsed.deinit();
    try max_options.setByRuleConfigValue("max-nested-callbacks", max_parsed.value);

    var max_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", max_options);
    defer max_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(max_result, lint.rules.max_nested_callbacks.id));

    const maximum_config =
        \\["error", { "maximum": 2 }]
    ;
    var maximum_options = baseOptions();
    var maximum_parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, maximum_config, .{});
    defer maximum_parsed.deinit();
    try maximum_options.setByRuleConfigValue("max-nested-callbacks", maximum_parsed.value);

    var maximum_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", maximum_options);
    defer maximum_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(maximum_result, lint.rules.max_nested_callbacks.id));
}

test "can disable max-nested-callbacks" {
    const source =
        \\first(function () {
        \\  second(function () {
        \\    done();
        \\  });
        \\});
    ;

    var options = baseOptions();
    options.max_nested_callbacks = false;
    options.max_nested_callbacks_max = 1;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.max_nested_callbacks.id));
}

fn baseOptions() lint.Options {
    return .{
        .max_depth = false,
        .max_statements = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_undef = false,
        .parser_semantic_errors = false,
        .typescript_eslint_no_empty_function = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.max_nested_callbacks.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
