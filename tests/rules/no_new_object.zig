const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-new-object for constructed global Object" {
    const source =
        \\const value = new Object();
        \\const wrapped = new (Object)();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_new_object.id));
}

test "does not report no-new-object for calls or shadowed Object" {
    const source =
        \\const value = Object();
        \\function local(Object) {
        \\  const value = new Object();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_new_object.id));
}

test "can disable no-new-object" {
    const source =
        \\const value = new Object();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new_object = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_new_object.id));
}
