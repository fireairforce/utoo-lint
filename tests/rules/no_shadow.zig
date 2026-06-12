const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-shadow for declarations in nested scopes" {
    const source =
        \\const a = 1;
        \\function f(a) {
        \\  let b = 1;
        \\  {
        \\    const b = 2;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_shadow.id));
}

test "does not report no-shadow for distinct sibling scopes or type declarations" {
    const source =
        \\function f() {
        \\  let a = 1;
        \\}
        \\function g() {
        \\  let a = 2;
        \\}
        \\interface Box {}
        \\function h() {
        \\  interface Box {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_shadow.id));
}

test "can disable no-shadow" {
    const source =
        \\let a = 1;
        \\function f() {
        \\  let a = 2;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_shadow = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_shadow.id));
}
