const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports object-shorthand for redundant property and method forms" {
    const source =
        \\const foo = 1;
        \\const obj = {
        \\  foo: foo,
        \\  bar: function () {
        \\    return 1;
        \\  },
        \\  asyncValue: async function () {
        \\    return 2;
        \\  },
        \\  "quoted": quoted,
        \\  "quoted-method": function () {
        \\    return 3;
        \\  },
        \\  [computedMethod]: function () {
        \\    return 4;
        \\  },
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.object_shorthand.id));
}

test "does not report object-shorthand for non-shorthandable properties" {
    const source =
        \\const foo = 1;
        \\const obj = {
        \\  foo,
        \\  foo: bar,
        \\  "foo": bar,
        \\  [foo]: foo,
        \\  method() {
        \\    return foo;
        \\  },
        \\  async asyncMethod() {
        \\    return foo;
        \\  },
        \\  bar: function named() {
        \\    return 1;
        \\  },
        \\  get value() {
        \\    return foo;
        \\  },
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.object_shorthand.id));
}

test "supports configured object-shorthand methods style" {
    const source =
        \\const obj = {
        \\  foo: foo,
        \\  bar: function () {
        \\    return 1;
        \\  },
        \\};
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"methods\"]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("object-shorthand", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.object_shorthand.id));
}

test "supports configured object-shorthand properties style" {
    const source =
        \\const obj = {
        \\  foo: foo,
        \\  bar: function () {
        \\    return 1;
        \\  },
        \\};
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"properties\"]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("object-shorthand", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.object_shorthand.id));
}

test "supports configured object-shorthand never style" {
    const source =
        \\const obj = {
        \\  foo,
        \\  bar() {
        \\    return 1;
        \\  },
        \\  baz: baz,
        \\};
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("object-shorthand", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.object_shorthand.id));
}

test "supports configured object-shorthand avoidQuotes option" {
    const source =
        \\const obj = {
        \\  foo: foo,
        \\  "quoted": quoted,
        \\  "quoted-method": function () {
        \\    return 1;
        \\  },
        \\};
    ;

    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"always\",{\"avoidQuotes\":true}]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("object-shorthand", config.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.object_shorthand.id));
}

test "can disable object-shorthand" {
    const source =
        \\const obj = {
        \\  foo: foo,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .object_shorthand = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.object_shorthand.id));
}
