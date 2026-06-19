const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports max-depth for deeply nested statements" {
    const source =
        \\function run() {
        \\  if (a) {
        \\    for (;;) {
        \\      while (b) {
        \\        switch (c) {
        \\          case 1:
        \\            try {
        \\              work();
        \\            } catch (error) {
        \\              recover(error);
        \\            }
        \\        }
        \\      }
        \\    }
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.max_depth.id));
    try std.testing.expect(hasMessage(result, "Maximum allowed is 4."));
}

test "supports configured max-depth max and deprecated maximum" {
    const source =
        \\if (a) {
        \\  if (b) {
        \\    work();
        \\  }
        \\}
    ;

    const max_config =
        \\["error", { "max": 1 }]
    ;
    var max_options = baseOptions();
    var max_parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, max_config, .{});
    defer max_parsed.deinit();
    try max_options.setByRuleConfigValue("max-depth", max_parsed.value);

    var max_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", max_options);
    defer max_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(max_result, lint.rules.max_depth.id));

    const maximum_config =
        \\["error", { "maximum": 2 }]
    ;
    var maximum_options = baseOptions();
    var maximum_parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, maximum_config, .{});
    defer maximum_parsed.deinit();
    try maximum_options.setByRuleConfigValue("max-depth", maximum_parsed.value);

    var maximum_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", maximum_options);
    defer maximum_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(maximum_result, lint.rules.max_depth.id));
}

test "does not count else-if chains as additional depth" {
    const source =
        \\if (a) {
        \\  work();
        \\} else if (b) {
        \\  work();
        \\} else if (c) {
        \\  if (d) {
        \\    work();
        \\  }
        \\}
    ;

    var options = baseOptions();
    options.max_depth_max = 1;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.max_depth.id));
}

test "calculates function and static block depth independently" {
    const source =
        \\if (outer) {
        \\  function nested() {
        \\    if (a) {
        \\      if (b) {
        \\        work();
        \\      }
        \\    }
        \\  }
        \\  class Example {
        \\    static {
        \\      if (c) {
        \\        if (d) {
        \\          work();
        \\        }
        \\      }
        \\    }
        \\  }
        \\}
    ;

    var options = baseOptions();
    options.max_depth_max = 1;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.max_depth.id));
}

test "can disable max-depth" {
    const source =
        \\if (a) {
        \\  if (b) {
        \\    work();
        \\  }
        \\}
    ;

    var options = baseOptions();
    options.max_depth = false;
    options.max_depth_max = 1;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.max_depth.id));
}

fn baseOptions() lint.Options {
    return .{
        .consistent_return = false,
        .curly = false,
        .no_constant_condition = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .typescript_eslint_no_empty_function = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.max_depth.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
