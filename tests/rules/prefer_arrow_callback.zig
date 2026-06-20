const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports function expression callbacks" {
    const source =
        \\items.map(function (item) {
        \\  return item.value;
        \\});
        \\setTimeout(function () {
        \\  work();
        \\}, 0);
        \\new Promise(function (resolve) {
        \\  resolve();
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.prefer_arrow_callback.id));
}

test "does not report non-callback function expressions or generators" {
    const source =
        \\const handler = function () {
        \\  return value;
        \\};
        \\items.map(function* generator() {
        \\  yield value;
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_arrow_callback.id));
}

test "supports named callback option" {
    var options = baseOptions();
    options.prefer_arrow_callback_allow_named_functions = true;

    const source =
        \\items.map(function named(item) {
        \\  return item.value;
        \\});
        \\items.map(function (item) {
        \\  return item.value;
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.prefer_arrow_callback.id));
}

test "supports allowUnboundThis and bound callbacks" {
    const source =
        \\items.map(function (item) {
        \\  return this.format(item);
        \\});
        \\items.map(function (item) {
        \\  return this.format(item);
        \\}.bind(this));
    ;

    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer default_result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(default_result, lint.rules.prefer_arrow_callback.id));

    var strict_options = baseOptions();
    strict_options.prefer_arrow_callback_allow_unbound_this = false;
    var strict_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", strict_options);
    defer strict_result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(strict_result, lint.rules.prefer_arrow_callback.id));
}

test "parses prefer-arrow-callback config and can disable" {
    var parsed = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\", {\"allowNamedFunctions\": true, \"allowUnboundThis\": false}]",
        .{},
    );
    defer parsed.deinit();

    var options = lint.Options.allDisabled();
    try options.setByRuleConfigValue("prefer-arrow-callback", parsed.value);

    try std.testing.expect(options.prefer_arrow_callback);
    try std.testing.expect(options.prefer_arrow_callback_allow_named_functions);
    try std.testing.expect(!options.prefer_arrow_callback_allow_unbound_this);

    try options.setByRuleConfigValue("prefer-arrow-callback", .{ .string = "off" });
    try std.testing.expect(!options.prefer_arrow_callback);
}

fn baseOptions() lint.Options {
    var options = lint.Options.allDisabled();
    options.prefer_arrow_callback = true;
    options.prefer_arrow_callback_allow_unbound_this = true;
    options.no_unassigned_vars = false;
    options.no_undef = false;
    options.no_unused_vars = false;
    options.parser_semantic_errors = false;
    return options;
}
