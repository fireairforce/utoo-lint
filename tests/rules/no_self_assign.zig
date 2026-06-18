const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-self-assign for equivalent assignment references" {
    const source =
        \\foo = foo;
        \\foo ||= foo;
        \\object.value = object.value;
        \\this.value = this["value"];
        \\object[`value`] = object[`value`];
        \\({ property: property } = { property: property });
        \\({ alias: renamed } = { alias: renamed });
        \\({ outer: { inner: inner } } = { outer: { inner: inner } });
        \\({ ["computed"]: computed } = { computed: computed });
        \\[first, second] = [other, second];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 10), helpers.countRule(result, lint.rules.no_self_assign.id));
}

test "does not report no-self-assign for different references or effectful objects" {
    const source =
        \\foo = bar;
        \\foo += foo;
        \\object.value = object.other;
        \\getObject().value = getObject().value;
        \\object[`val${suffix}`] = object[`val${suffix}`];
        \\({ property: property } = { other: property });
        \\({ property: property } = { property: other });
        \\({ property: property = fallback } = { property: property });
        \\({ [dynamic]: property } = { [dynamic]: property });
        \\[first] = [second];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_self_assign.id));
}

test "supports configured no-self-assign props false" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"props\":false}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("no-self-assign", config.value);

    const source =
        \\foo = foo;
        \\object.value = object.value;
        \\this.value = this["value"];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_self_assign.id));
}

test "can disable no-self-assign" {
    const source =
        \\foo = foo;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_self_assign = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_self_assign.id));
}
