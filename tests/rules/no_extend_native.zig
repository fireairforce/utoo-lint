const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-extend-native for native prototype assignments" {
    const source =
        \\String.prototype.trimLeft = function () {};
        \\Array.prototype["first"] = function () {};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .typescript_eslint_no_empty_function = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_extend_native.id));
    try std.testing.expectEqualStrings("String prototype is read only, properties should not be added.", result.diagnostics[0].message);
}

test "reports no-extend-native for Object defineProperty calls" {
    const source =
        \\Object.defineProperty(Date.prototype, "week", { value: function () {} });
        \\Object.defineProperties(Map.prototype, {
        \\  first: { value: function () {} },
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .typescript_eslint_no_empty_function = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_extend_native.id));
}

test "does not report no-extend-native for shadowed constructors or ordinary objects" {
    const source =
        \\const String = {};
        \\String.prototype.trimLeft = function () {};
        \\const local = { prototype: {} };
        \\local.prototype.trimLeft = function () {};
        \\const Object = {
        \\  defineProperty() {},
        \\};
        \\Object.defineProperty(Array.prototype, "first", {});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .typescript_eslint_no_empty_function = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_extend_native.id));
}

test "can disable no-extend-native" {
    const source =
        \\String.prototype.trimLeft = function () {};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_extend_native = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .typescript_eslint_no_empty_function = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_extend_native.id));
}
