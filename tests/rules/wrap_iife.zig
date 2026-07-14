const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports wrap-iife for unwrapped and inside-wrapped IIFEs" {
    const source =
        \\const first = function () {
        \\  return value;
        \\}();
        \\const second = (function () {
        \\  return value;
        \\})();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.wrap_iife.id));
    try std.testing.expectEqualStrings("Wrap an immediate function invocation in parentheses.", result.diagnostics[0].message);
}

test "autofixes unwrapped and inside-wrapped IIFEs to outside style" {
    const source =
        \\const first = function () {
        \\  return value;
        \\}();
        \\const second = (function () {
        \\  return value;
        \\})();
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\const first = (function () {
        \\  return value;
        \\}());
        \\const second = (function () {
        \\  return value;
        \\}());
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.wrap_iife.id));
}

test "allows outside-wrapped IIFEs and non-IIFE calls" {
    const source =
        \\const first = (function () {
        \\  return value;
        \\}());
        \\const second = callback(function () {
        \\  return value;
        \\});
        \\const third = (() => value)();
        \\const fourth = function () {
        \\  return value;
        \\}.call(context);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.wrap_iife.id));
}

test "supports inside style" {
    const source =
        \\const outside = (function () {
        \\  return value;
        \\}());
        \\const inside = (function () {
        \\  return value;
        \\})();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .wrap_iife_style = .inside,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.wrap_iife.id));
}

test "autofixes unwrapped and outside-wrapped IIFEs to inside style" {
    const source =
        \\const first = function () {
        \\  return value;
        \\}();
        \\const second = (function () {
        \\  return value;
        \\}());
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .wrap_iife_style = .inside,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\const first = (function () {
        \\  return value;
        \\})();
        \\const second = (function () {
        \\  return value;
        \\})();
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.wrap_iife.id));
}

test "supports any style" {
    const source =
        \\const unwrapped = function () {
        \\  return value;
        \\}();
        \\const outside = (function () {
        \\  return value;
        \\}());
        \\const inside = (function () {
        \\  return value;
        \\})();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .wrap_iife_style = .any,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.wrap_iife.id));
}

test "autofixes only unwrapped IIFEs in any style" {
    const source =
        \\const unwrapped = function () { return value; }();
        \\const outside = (function () { return value; }());
        \\const inside = (function () { return value; })();
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .wrap_iife_style = .any,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        \\const unwrapped = (function () { return value; }());
        \\const outside = (function () { return value; }());
        \\const inside = (function () { return value; })();
    , result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.wrap_iife.id));
}

test "can disable wrap-iife" {
    const source = "const value = function () { return 1; }();\n";

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .wrap_iife = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.wrap_iife.id));
}
