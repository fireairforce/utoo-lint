const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-new-wrappers for global wrapper constructors" {
    const source =
        \\const string = new String("text");
        \\const number = new Number(1);
        \\const boolean = new Boolean(false);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_new_wrappers.id));
}

test "does not report no-new-wrappers for calls or shadowed constructors" {
    const source =
        \\const string = String(value);
        \\const number = Number(value);
        \\const boolean = Boolean(value);
        \\function local(String) {
        \\  const value = new String("text");
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_new_wrappers.id));
}

test "can disable no-new-wrappers" {
    const source =
        \\const string = new String("text");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new_wrappers = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_new_wrappers.id));
}
