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

test "autofixes anonymous synchronous callback functions" {
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
        \\items.map(function () { return function () { return arguments[0]; }; });
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\items.map((item) => {
        \\  return item.value;
        \\});
        \\setTimeout(() => {
        \\  work();
        \\}, 0);
        \\new Promise((resolve) => {
        \\  resolve();
        \\});
        \\items.map(() => { return function () { return arguments[0]; }; });
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.prefer_arrow_callback.id));
}

test "autofix preserves parameter and body comments" {
    const source =
        \\items.map(function /* keyword */ (blocked) { return blocked; });
        \\items.map(function (/* parameter */ item) { /* body */ return item; });
    ;

    var options = baseOptions();
    options.capitalized_comments = false;
    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\items.map(function /* keyword */ (blocked) { return blocked; });
        \\items.map((/* parameter */ item) => { /* body */ return item; });
    , result.output);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result.result, lint.rules.prefer_arrow_callback.id));
    try std.testing.expectEqual(@as(usize, 0), result.result.diagnostics[0].fixes.len);
}

test "autofix refuses callbacks with lexical or syntactic hazards" {
    const source =
        \\items.map(function named(item) { return item; });
        \\items.map(function (item, item) { return item; });
        \\items.map(function () { return arguments[0]; });
        \\items.map(function () { return () => arguments[0]; });
        \\items.map(function () { return this.value; });
        \\items.map(function () { return new.target; });
        \\items.map(function () {}.bind(this));
        \\items.map(async function (item) { return item; });
        \\items.map(function (safe) { return safe; });
    ;

    var options = baseOptions();
    options.prefer_arrow_callback_allow_unbound_this = false;
    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\items.map(function named(item) { return item; });
        \\items.map(function (item, item) { return item; });
        \\items.map(function () { return arguments[0]; });
        \\items.map(function () { return () => arguments[0]; });
        \\items.map(function () { return this.value; });
        \\items.map(function () { return new.target; });
        \\items.map(function () {}.bind(this));
        \\items.map(async function (item) { return item; });
        \\items.map((safe) => { return safe; });
    , result.output);
    try std.testing.expectEqual(@as(usize, 8), helpers.countRule(result.result, lint.rules.prefer_arrow_callback.id));
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.prefer_arrow_callback.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
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
