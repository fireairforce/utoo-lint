const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-else-return after returning consequent" {
    const source =
        \\function first(value) {
        \\  if (value) {
        \\    return 1;
        \\  } else {
        \\    return 2;
        \\  }
        \\}
        \\function second(value) {
        \\  if (value) throw error;
        \\  else return 2;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_else_return.id));
}

test "does not report no-else-return when consequent can continue" {
    const source =
        \\function first(value) {
        \\  if (value) {
        \\    use(value);
        \\  } else {
        \\    return 2;
        \\  }
        \\}
        \\function second(value) {
        \\  if (value) return 1;
        \\  return 2;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_else_return.id));
}

test "does not report no-else-return for else-if alternate" {
    const source =
        \\function first(value) {
        \\  if (value) {
        \\    return 1;
        \\  } else if (value > 1) {
        \\    return 2;
        \\  }
        \\}
        \\function second(value) {
        \\  if (value) return 1;
        \\  else if (value > 1) return 2;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_else_return.id));
}

test "reports no-else-return for else-if alternate when allowElseIf is false" {
    const source =
        \\function first(value) {
        \\  if (value) {
        \\    return 1;
        \\  } else if (value > 1) {
        \\    return 2;
        \\  }
        \\}
        \\function second(value) {
        \\  if (value) return 1;
        \\  else if (value > 1) return 2;
        \\}
    ;

    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowElseIf\":false}]",
        .{},
    );
    defer config.deinit();
    try options.setByRuleConfigValue("no-else-return", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_else_return.id));
}

test "can disable no-else-return" {
    const source =
        \\function first(value) {
        \\  if (value) return 1;
        \\  else return 2;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_else_return = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_else_return.id));
}
