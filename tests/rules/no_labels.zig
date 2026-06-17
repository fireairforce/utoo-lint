const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-labels for labeled statements" {
    const source =
        \\start:
        \\for (const item of items) {
        \\  if (item) break start;
        \\}
        \\again:
        \\while (ready) {
        \\  continue again;
        \\}
        \\done:
        \\use(value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_labels.id));
}

test "does not report no-labels for unlabeled break and continue" {
    const source =
        \\for (const item of items) {
        \\  if (item) break;
        \\  continue;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_labels.id));
}

test "supports configured no-labels allowLoop" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowLoop\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-labels", config.value);
    options.no_unused_vars = false;
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\loop:
        \\for (const item of items) {
        \\  if (item) break loop;
        \\  continue loop;
        \\}
        \\switchLabel:
        \\switch (value) {
        \\  case 1:
        \\    break switchLabel;
        \\}
        \\plain:
        \\use(value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_labels.id));
}

test "supports configured no-labels allowSwitch" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"allowSwitch\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-labels", config.value);
    options.no_continue = false;
    options.no_unused_vars = false;
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\loop:
        \\for (const item of items) {
        \\  if (item) break loop;
        \\  continue loop;
        \\}
        \\switchLabel:
        \\switch (value) {
        \\  case 1:
        \\    break switchLabel;
        \\}
        \\plain:
        \\use(value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_labels.id));
}

test "can disable no-labels" {
    const source =
        \\start:
        \\for (const item of items) {
        \\  if (item) break start;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_labels = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_labels.id));
}
