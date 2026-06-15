const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-void for void unary expressions" {
    const source =
        \\void 0;
        \\function f() {
        \\  return void 0;
        \\}
        \\const value = void(0);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_void.id));
}

test "does not report no-void for delete or property names" {
    const source =
        \\delete object.value;
        \\object.void();
        \\object.void = value;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_console = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_void.id));
}

test "allows void expression statements when allowAsStatement is enabled" {
    const source =
        \\void doSideEffect();
        \\(void doSideEffect());
        \\((void doSideEffect()));
        \\function f() {
        \\  return void doSideEffect();
        \\}
        \\const value = void doSideEffect();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_void_allow_as_statement = .yes,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_void.id));
}

test "can disable no-void" {
    const source =
        \\void 0;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_void = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_void.id));
}
