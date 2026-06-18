const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports use-isnan for comparisons with NaN" {
    const source =
        \\if (value == NaN) { use(value); }
        \\if (NaN !== value) { use(value); }
        \\if ((value) != (NaN)) { use(value); }
        \\if (value > NaN) { use(value); }
        \\if (Number.NaN <= value) { use(value); }
        \\if (value === Number["NaN"]) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.use_isnan.id));
}

test "reports use-isnan for switch cases by default" {
    const source =
        \\switch (value) {
        \\  case NaN:
        \\    use(value);
        \\  case Number.NaN:
        \\    use(value);
        \\}
        \\switch (NaN) {
        \\  case value:
        \\    use(value);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.use_isnan.id));
}

test "supports configured use-isnan switch case enforcement false" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"enforceForSwitchCase\":false}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("use-isnan", config.value);

    const source =
        \\switch (value) {
        \\  case NaN:
        \\    use(value);
        \\}
        \\if (value === NaN) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.use_isnan.id));
}

test "supports configured use-isnan indexOf enforcement" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"enforceForIndexOf\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("use-isnan", config.value);

    const source =
        \\values.indexOf(NaN);
        \\values.lastIndexOf(Number.NaN);
        \\values.includes(NaN);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.use_isnan.id));
}

test "does not report use-isnan for indexOf by default or Number.isNaN" {
    const source =
        \\values.indexOf(NaN);
        \\values.lastIndexOf(Number.NaN);
        \\if (Number.isNaN(value)) { use(value); }
        \\if (isNaN(value)) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.use_isnan.id));
}

test "can disable use-isnan" {
    const source =
        \\if (value === NaN) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .use_isnan = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.use_isnan.id));
}
