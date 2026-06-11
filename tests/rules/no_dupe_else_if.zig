const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-dupe-else-if for repeated else-if conditions" {
    const source =
        \\if (a) {
        \\  first();
        \\} else if (b) {
        \\  second();
        \\} else if (a) {
        \\  third();
        \\}
        \\if (x === y) {
        \\  first();
        \\} else if (x === y) {
        \\  second();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_dupe_else_if.id));
}

test "reports no-dupe-else-if for conditions covered by previous logical conditions" {
    const source =
        \\if (a || b) {
        \\  first();
        \\} else if (a) {
        \\  second();
        \\}
        \\if (c) {
        \\  first();
        \\} else if (d) {
        \\  second();
        \\} else if (c || d) {
        \\  third();
        \\}
        \\if (ready) {
        \\  first();
        \\} else if (ready && enabled) {
        \\  second();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_dupe_else_if.id));
}

test "does not report no-dupe-else-if for distinct reachable else-if conditions" {
    const source =
        \\if (a) {
        \\  first();
        \\} else if (b) {
        \\  second();
        \\} else if (a || b || c) {
        \\  third();
        \\}
        \\if (ready && enabled) {
        \\  first();
        \\} else if (ready && disabled) {
        \\  second();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_dupe_else_if.id));
}

test "can disable no-dupe-else-if" {
    const source =
        \\if (a) {
        \\  first();
        \\} else if (a) {
        \\  second();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_dupe_else_if = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_dupe_else_if.id));
}
