const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports complexity above the configured maximum" {
    const source =
        \\function run(value) {
        \\  if (value) {
        \\    while (value.ready) {
        \\      value.next();
        \\    }
        \\  }
        \\}
    ;

    var options = baseOptions();
    options.complexity_max = 2;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.complexity.id));
    try std.testing.expect(hasMessage(result, "Function has a complexity of 3. Maximum allowed is 2."));
}

test "counts expression branches and optional chaining" {
    const source =
        \\const run = (value = fallback, obj) => {
        \\  if (value && obj?.ready) {
        \\    value ||= other ? one() : two();
        \\  }
        \\  return obj?.call?.();
        \\};
    ;

    var options = baseOptions();
    options.complexity_max = 6;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.complexity.id));
    try std.testing.expect(hasMessage(result, "Arrow function has a complexity of 9. Maximum allowed is 6."));
}

test "supports classic and modified switch variants" {
    const source =
        \\function run(value) {
        \\  switch (value) {
        \\    case 1:
        \\      break;
        \\    case 2:
        \\      break;
        \\    default:
        \\      break;
        \\  }
        \\}
    ;

    var classic_options = baseOptions();
    classic_options.complexity_max = 2;

    var classic_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", classic_options);
    defer classic_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(classic_result, lint.rules.complexity.id));

    var modified_options = classic_options;
    modified_options.complexity_variant = .modified;

    var modified_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", modified_options);
    defer modified_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(modified_result, lint.rules.complexity.id));
}

test "supports complexity config object and deprecated maximum" {
    const source =
        \\function run(value) {
        \\  if (value) {
        \\    return one();
        \\  }
        \\  return two();
        \\}
    ;

    const config =
        \\["error", { "maximum": 1, "variant": "modified" }]
    ;

    var options = baseOptions();
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, config, .{});
    defer parsed.deinit();
    try options.setByRuleConfigValue("complexity", parsed.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.complexity.id));
    try std.testing.expectEqualStrings("modified", @tagName(options.complexity_variant));
}

test "reports class static block complexity" {
    const source =
        \\class Example {
        \\  static {
        \\    if (ready) {
        \\      work();
        \\    }
        \\  }
        \\}
    ;

    var options = baseOptions();
    options.complexity_max = 1;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.complexity.id));
    try std.testing.expect(hasMessage(result, "Class static block has a complexity of 2. Maximum allowed is 1."));
}

test "can disable complexity" {
    const source =
        \\function run(value) {
        \\  if (value) {
        \\    return one();
        \\  }
        \\}
    ;

    var options = baseOptions();
    options.complexity = false;
    options.complexity_max = 1;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.complexity.id));
}

fn baseOptions() lint.Options {
    return .{
        .complexity = true,
        .curly = false,
        .max_depth = false,
        .max_statements = false,
        .no_empty = false,
        .no_empty_block_statements = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.complexity.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
