const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-useless-computed-key for object and pattern literal keys" {
    const source =
        \\const object = {
        \\  ["name"]: value,
        \\  [0]: value,
        \\  ["method"]() {},
        \\};
        \\const { ["name"]: name, [0]: zero } = object;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_useless_computed_key.id));
}

test "reports no-useless-computed-key for class members with literal keys" {
    const source =
        \\class Example {
        \\  ["method"]() {}
        \\  get ["value"]() {
        \\    return value;
        \\  }
        \\  ["field"] = value;
        \\  static ["name"]() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_useless_computed_key.id));
}

test "does not report no-useless-computed-key for dynamic keys or semantic exceptions" {
    const source =
        \\const object = {
        \\  [name]: value,
        \\  ["__proto__"]: value,
        \\};
        \\const { [name]: local } = object;
        \\class Example {
        \\  ["constructor"]() {}
        \\  static ["prototype"]() {}
        \\  [name]() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_computed_key.id));
}

test "can disable no-useless-computed-key" {
    const source =
        \\const object = {
        \\  ["name"]: value,
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_useless_computed_key = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_computed_key.id));
}
