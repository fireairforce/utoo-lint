const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports symbol-description for Symbol calls without a description" {
    const source =
        \\const foo = Symbol();
        \\const bar = (Symbol)();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.symbol_description.id));
}

test "does not report symbol-description with arguments or shadowed Symbol" {
    const source =
        \\const foo = Symbol("foo");
        \\const bar = Symbol(undefined);
        \\function local(Symbol) {
        \\  const baz = Symbol();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.symbol_description.id));
}

test "can disable symbol-description" {
    const source =
        \\const foo = Symbol();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .symbol_description = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.symbol_description.id));
}
