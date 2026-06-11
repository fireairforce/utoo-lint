const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-useless-catch for catch clauses that only rethrow" {
    const source =
        \\try {
        \\  risky();
        \\} catch (error) {
        \\  throw error;
        \\}
        \\try {
        \\  risky();
        \\} catch (reason) {
        \\  throw (reason);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_useless_catch.id));
}

test "does not report no-useless-catch for useful catch clauses" {
    const source =
        \\try {
        \\  risky();
        \\} catch (error) {
        \\  report(error);
        \\  throw error;
        \\}
        \\try {
        \\  risky();
        \\} catch (error) {
        \\  throw wrap(error);
        \\}
        \\try {
        \\  risky();
        \\} catch {
        \\  throw error;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_catch.id));
}

test "can disable no-useless-catch" {
    const source =
        \\try {
        \\  risky();
        \\} catch (error) {
        \\  throw error;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_useless_catch = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_catch.id));
}
