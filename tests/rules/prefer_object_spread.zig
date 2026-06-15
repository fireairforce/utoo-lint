const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports prefer-object-spread for Object.assign into object literals" {
    const source =
        \\const first = Object.assign({}, source);
        \\const second = Object.assign({ value: 1 }, source, extra);
        \\const third = Object["assign"]({}, source);
        \\const fourth = Object[`assign`]({}, source);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .dot_notation = false,
        .typescript_eslint_dot_notation = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.prefer_object_spread.id));
    try std.testing.expectEqualStrings("Use an object spread instead of Object.assign.", result.diagnostics[0].message);
}

test "allows non-object targets shadowed Object and spread arguments" {
    const source =
        \\const target = {};
        \\Object.assign(target, source);
        \\Object.assign({}, ...sources);
        \\Object[assign]({}, source);
        \\Object[`assi${name}`]({}, source);
        \\function local(Object) {
        \\  Object.assign({}, source);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_object_spread.id));
}

test "can disable prefer-object-spread" {
    const source = "const value = Object.assign({}, source);\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .prefer_object_spread = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_object_spread.id));
}
