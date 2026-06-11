const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-const-assign for reassigned const bindings" {
    const source =
        \\const first = 1;
        \\first = 2;
        \\const second = 1;
        \\second += 2;
        \\const third = 1;
        \\third++;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_plusplus = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_const_assign.id));
}

test "does not report no-const-assign for let bindings or member writes" {
    const source =
        \\let value = 1;
        \\value = 2;
        \\const object = {};
        \\object.value = 1;
        \\function update(value) {
        \\  value = 3;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_const_assign.id));
}

test "can disable no-const-assign" {
    const source =
        \\const first = 1;
        \\first = 2;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_const_assign = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_const_assign.id));
}
