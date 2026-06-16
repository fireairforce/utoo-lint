const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "does not report no-inner-declarations for block-scoped function declarations by default" {
    const source =
        \\if (foo) {
        \\  function bar() {}
        \\}
        \\while (foo) {
        \\  function baz() {}
        \\}
        \\{
        \\  function qux() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_constant_condition = false,
        .no_lone_blocks = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_inner_declarations.id));
}

test "does not report no-inner-declarations for root function declarations" {
    const source =
        \\function topLevel() {}
        \\function outer() {
        \\  function inner() {}
        \\  const fn = function expression() {};
        \\}
        \\export function exported() {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_inner_declarations.id));
}

test "can disable no-inner-declarations" {
    const source =
        \\if (foo) {
        \\  function bar() {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_inner_declarations = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_inner_declarations.id));
}
