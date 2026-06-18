const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-param-reassign for assigning to function parameters" {
    const source =
        \\function run(value, count = 0, ...rest) {
        \\  value = next;
        \\  count += 1;
        \\  rest++;
        \\}
        \\const arrow = (item) => item = next;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .no_plusplus = false,
        .operator_assignment = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_param_reassign.id));
}

test "reports no-param-reassign for destructured parameter bindings" {
    const source =
        \\function run({ value }, [count]) {
        \\  value = next;
        \\  count++;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .no_plusplus = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_param_reassign.id));
}

test "reports no-param-reassign for outer parameter writes inside nested functions" {
    const source =
        \\function run(value) {
        \\  function nested() {
        \\    value = next;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_inner_declarations = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_param_reassign.id));
}

test "does not report no-param-reassign for property writes or shadowed local assignments" {
    const source =
        \\function run(value) {
        \\  value.name = next;
        \\  other = value;
        \\  function nested() {
        \\    let value;
        \\    value = next;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_param_reassign.id));
}

test "reports no-param-reassign for parameter property writes when props is enabled" {
    const source =
        \\function run(value, other) {
        \\  value.name = next;
        \\  value.name++;
        \\  delete value.name;
        \\  for (value.name in source) {
        \\    run(value);
        \\  }
        \\  for (value.item of source) {
        \\    run(value);
        \\  }
        \\  other.nested.value = next;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_param_reassign_props = .yes,
        .no_undef = false,
        .no_unused_vars = false,
        .no_plusplus = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.no_param_reassign.id));
}

test "allows configured parameter property modification names" {
    const source =
        \\function middleware(req, res, ctx) {
        \\  req.body = next;
        \\  res.statusCode++;
        \\  delete req.headers;
        \\  ctx.value = next;
        \\  req = next;
        \\}
    ;

    var ignored = (lint.Options{}).no_param_reassign_ignore_property_modifications_for;
    try ignored.append("req");
    try ignored.append("res");

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_param_reassign_props = .yes,
        .no_param_reassign_ignore_property_modifications_for = ignored,
        .no_undef = false,
        .no_unused_vars = false,
        .no_plusplus = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_param_reassign.id));
}

test "allows configured parameter property modification name patterns" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"props\":true,\"ignorePropertyModificationsFor\":[\"exact\"],\"ignorePropertyModificationsForRegex\":[\"^req\",\"Response$\"]}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-param-reassign", config.value);
    options.no_undef = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;

    const source =
        \\function middleware(req, apiResponse, exact, ctx) {
        \\  req.body = next;
        \\  apiResponse.statusCode = next;
        \\  exact.value = next;
        \\  ctx.value = next;
        \\  req = next;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_param_reassign.id));
}

test "can disable no-param-reassign" {
    const source =
        \\function run(value) {
        \\  value = next;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_param_reassign = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_param_reassign.id));
}
