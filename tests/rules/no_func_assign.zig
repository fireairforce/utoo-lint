const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-func-assign for reassigned function bindings" {
    const source =
        \\function first() {}
        \\first = replacement;
        \\function second() {}
        \\second += replacement;
        \\function third() {}
        \\third++;
        \\const fn = function named() {
        \\  named = replacement;
        \\  named++;
        \\};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_plusplus = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_func_assign.id));
}

test "does not report no-func-assign for shadowed variables or member assignments" {
    const source =
        \\function outer(value) {
        \\  value = 1;
        \\}
        \\function wrapper() {
        \\  let outer = 1;
        \\  outer = 2;
        \\}
        \\const object = {};
        \\object.outer = 3;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_func_assign.id));
}

test "can disable no-func-assign" {
    const source =
        \\function first() {}
        \\first = replacement;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_func_assign = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_func_assign.id));
}
