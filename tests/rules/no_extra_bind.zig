const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-extra-bind for functions that do not use this" {
    const source =
        \\const first = function () {
        \\  return value;
        \\}.bind(context);
        \\const second = function () {
        \\  return value;
        \\}.bind();
        \\const third = function () {
        \\  return value;
        \\}[`bind`](context);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_extra_bind.id));
    try std.testing.expectEqualStrings("The function binding is unnecessary.", result.diagnostics[0].message);
}

test "reports no-extra-bind for arrow functions" {
    const source =
        \\const first = (() => value).bind(context);
        \\const second = (() => this.value).bind(context);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_extra_bind.id));
}

test "does not report no-extra-bind when this or bound arguments are used" {
    const source =
        \\const first = function () {
        \\  return this.value;
        \\}.bind(context);
        \\const second = function (value) {
        \\  return value + 1;
        \\}.bind(context, value);
        \\const third = ((value) => value + 1).bind(context, value);
        \\const fourth = function () {
        \\  return value;
        \\}[`bi${suffix}`](context);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_extra_bind.id));
}

test "does not count this inside nested functions" {
    const source =
        \\const first = function () {
        \\  function nested() {
        \\    return this.value;
        \\  }
        \\  return nested();
        \\}.bind(context);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_extra_bind.id));
}

test "can disable no-extra-bind" {
    const source =
        \\const first = function () {
        \\  return value;
        \\}.bind(context);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_extra_bind = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_extra_bind.id));
}
