const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-extra-boolean-cast in boolean contexts" {
    const source =
        \\if (Boolean(value)) { use(value); }
        \\while (!!value) { break; }
        \\do { value++; } while (Boolean(value));
        \\for (; !!value; value++) { break; }
        \\const selected = Boolean(value) ? 1 : 2;
        \\function local(Boolean) {
        \\  if (Boolean(value)) { use(value); }
        \\}
        \\if (Boolean?.(value)) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.no_extra_boolean_cast.id));
}

test "does not report no-extra-boolean-cast outside boolean contexts or member calls" {
    const source =
        \\const a = Boolean(value);
        \\const b = !!value;
        \\if (globalThis.Boolean(value)) { use(value); }
        \\if (obj.Boolean(value)) { use(value); }
        \\if (!value) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_extra_boolean_cast.id));
}

test "reports no-extra-boolean-cast inner expressions when configured" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"enforceForInnerExpressions\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-extra-boolean-cast", config.value);
    options.no_unused_vars = false;
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\if (foo && !!bar) { use(bar); }
        \\if (foo || Boolean(bar)) { use(bar); }
        \\const value = foo && !!bar;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_extra_boolean_cast.id));
}

test "supports deprecated no-extra-boolean-cast enforceForLogicalOperands option" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"enforceForLogicalOperands\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-extra-boolean-cast", config.value);
    options.no_unused_vars = false;
    options.no_undef = false;
    options.parser_semantic_errors = false;

    const source =
        \\if (foo && !!bar) { use(bar); }
        \\if (foo || Boolean(bar)) { use(bar); }
        \\const value = foo && !!bar;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_extra_boolean_cast.id));
}

test "reports no-extra-boolean-cast inside negated boolean contexts" {
    const source =
        \\if (!Boolean(value)) { use(value); }
        \\while (!!!value) { break; }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_extra_boolean_cast.id));
}

test "does not report negated boolean casts outside boolean contexts" {
    const source =
        \\const a = !Boolean(value);
        \\const b = !!!value;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_extra_boolean_cast.id));
}

test "can disable no-extra-boolean-cast" {
    const source =
        \\if (Boolean(value)) { use(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_extra_boolean_cast = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_extra_boolean_cast.id));
}
