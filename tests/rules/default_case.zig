const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports default-case for switch statements without default" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    runOne();
        \\    break;
        \\}
        \\switch (commentBeforeCase) {
        \\  // no default
        \\  case 1:
        \\    runOne();
        \\}
        \\switch (commentWithExplanation) {
        \\  case 1:
        \\    runOne();
        \\  // no default: handled elsewhere
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.default_case.id));
}

test "does not report default-case when default exists or comment opts out" {
    const source =
        \\switch (first) {
        \\  case 1:
        \\    runOne();
        \\    break;
        \\  default:
        \\    runDefault();
        \\}
        \\switch (second) {
        \\  case 1:
        \\    runOne();
        \\  // no default
        \\}
        \\switch (third) {
        \\  case 1:
        \\    runOne();
        \\  /* No Default */
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.default_case.id));
}

test "supports configured default-case commentPattern option" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"commentPattern\":\"^skip default|covered elsewhere$\"}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("default-case", config.value);

    const source =
        \\switch (first) {
        \\  case 1:
        \\    runOne();
        \\  // skip default because values are normalized
        \\}
        \\switch (second) {
        \\  case 1:
        \\    runOne();
        \\  // handled by covered elsewhere
        \\}
        \\switch (third) {
        \\  case 1:
        \\    runOne();
        \\  // no default
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.default_case.id));
}

test "can disable default-case" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    runOne();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .default_case = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.default_case.id));
}
