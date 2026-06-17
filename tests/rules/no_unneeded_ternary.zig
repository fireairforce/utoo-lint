const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-unneeded-ternary for boolean literal branches" {
    const source =
        \\const first = enabled ? true : false;
        \\const second = enabled ? false : true;
        \\const third = enabled ? true : true;
        \\const fourth = enabled ? false : false;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_ternary = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_unneeded_ternary.id));
}

test "does not report no-unneeded-ternary for non-boolean branches or default assignments" {
    const source =
        \\const first = enabled ? value : fallback;
        \\const second = enabled ? enabled : fallback;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_ternary = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unneeded_ternary.id));
}

test "supports configured no-unneeded-ternary defaultAssignment false" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"defaultAssignment\":false}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-unneeded-ternary", config.value);
    options.no_ternary = false;
    options.no_constant_condition = false;
    options.no_unused_vars = false;
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\const first = enabled ? enabled : fallback;
        \\const second = (ready) ? (ready) : fallback;
        \\const third = enabled ? value : enabled;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_unneeded_ternary.id));
}

test "can disable no-unneeded-ternary" {
    const source =
        \\const value = enabled ? true : false;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unneeded_ternary = false,
        .no_ternary = false,
        .no_constant_condition = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unneeded_ternary.id));
}
