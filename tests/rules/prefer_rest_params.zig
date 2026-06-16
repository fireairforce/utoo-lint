const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports prefer-rest-params for current function arguments usage" {
    const source =
        \\function first() {
        \\  return arguments[0];
        \\}
        \\const second = function () {
        \\  return arguments.length;
        \\};
        \\const obj = {
        \\  method() {
        \\    return arguments[0];
        \\  }
        \\};
        \\function withRest(...args) {
        \\  return arguments[0];
        \\}
        \\function nestedOnly() {
        \\  function inner(...args) {
        \\    return arguments[0];
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.prefer_rest_params.id));
}

test "does not report prefer-rest-params for nested or arrow arguments usage" {
    const source =
        \\function nestedOnly() {
        \\  function inner(arguments) {
        \\    return arguments[0];
        \\  }
        \\}
        \\const arrow = () => arguments;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_rest_params.id));
}

test "reports prefer-rest-params for each arguments reference" {
    const source =
        \\function multiple() {
        \\  arguments;
        \\  return arguments[0];
        \\}
        \\function arrowInside() {
        \\  const read = () => arguments.length;
        \\  return read;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.prefer_rest_params.id));
}

test "does not report prefer-rest-params when arguments is shadowed in scripts" {
    const source =
        \\function parameter(arguments) {
        \\  return arguments;
        \\}
        \\function local() {
        \\  var arguments = value;
        \\  return arguments;
        \\}
        \\function arguments() {
        \\  return arguments;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", .{
        .no_shadow_restricted_names = false,
        .no_var = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_rest_params.id));
}

test "does not report prefer-rest-params when arguments declaration follows usage" {
    const source =
        \\function local() {
        \\  const first = arguments;
        \\  var arguments = value;
        \\  return first;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", .{
        .no_shadow_restricted_names = false,
        .no_var = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_rest_params.id));
}

test "can disable prefer-rest-params" {
    const source =
        \\function first() {
        \\  return arguments[0];
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .prefer_rest_params = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_rest_params.id));
}
