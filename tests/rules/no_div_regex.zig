const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-div-regex for regex literals that start with equals" {
    const source =
        \\function value() {
        \\  return /=foo/;
        \\}
        \\const pattern = /=bar/u;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_div_regex.id));
}

test "does not report no-div-regex for ordinary regex literals" {
    const source =
        \\const first = /foo=/;
        \\const second = /foo/;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_div_regex.id));
}

test "autofixes regex literals that can be confused with division assignment" {
    const source =
        \\function value() {
        \\  return /=foo/;
        \\}
        \\const pattern = /=bar/u;
    ;
    const expected =
        \\function value() {
        \\  return /[=]foo/;
        \\}
        \\const pattern = /[=]bar/u;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.no_div_regex.id));
}

test "can disable no-div-regex" {
    const source =
        \\const pattern = /=foo/;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_div_regex = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_div_regex.id));
}
