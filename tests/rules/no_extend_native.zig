const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-extend-native for native prototype assignments" {
    const source =
        \\Object.prototype.toJSON = function () {};
        \\String.prototype.trimLeft = function () {};
        \\Array.prototype["first"] = function () {};
        \\Array[`prototype`].first = function () {};
        \\const Boolean = CustomBoolean;
        \\Boolean.prototype.value = function () {};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .func_names = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .typescript_eslint_no_empty_function = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_extend_native.id));
    try std.testing.expectEqualStrings("Object prototype is read only, properties should not be added.", result.diagnostics[0].message);
}

test "reports no-extend-native for Object defineProperty calls" {
    const source =
        \\Object.defineProperty(Date.prototype, "week", { value: function () {} });
        \\Object[`defineProperty`](Array.prototype, "first", {});
        \\Object.defineProperties(Map.prototype, {
        \\  first: { value: function () {} },
        \\});
        \\Object[`defineProperties`](Set.prototype, {
        \\  first: { value: function () {} },
        \\});
        \\Object.defineProperty?.(Date.prototype, "day", {});
        \\Object?.defineProperty(Array.prototype, "second", {});
        \\Object?.["defineProperty"](Map.prototype, "second", {});
        \\Object?.[`defineProperties`](Set.prototype, {
        \\  second: { value: function () {} },
        \\});
        \\Object.defineProperty(Array?.prototype, "maybe", {});
        \\Object.defineProperty(Array?.["prototype"], "maybeComputed", {});
        \\const Object = {
        \\  defineProperty() {},
        \\};
        \\Object.defineProperty(Array.prototype, "last", {});
        \\const Array = CustomArray;
        \\Object.defineProperty(Array.prototype, "shadowed", {});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .func_names = false,
        .no_empty_block_statements = false,
        .no_empty_function = false,
        .no_undef = false,
        .no_unused_vars = false,
        .typescript_eslint_dot_notation = false,
        .typescript_eslint_no_empty_function = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 12), helpers.countRule(result, lint.rules.no_extend_native.id));
}

test "does not report no-extend-native for ordinary objects or dynamic members" {
    const source =
        \\const local = { prototype: {} };
        \\local.prototype.trimLeft = function () {};
        \\Array[`proto${suffix}`].first = function () {};
        \\Object[`define${suffix}`](Array.prototype, "first", {});
        \\Object?.[`define${suffix}`](Array.prototype, "first", {});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .func_names = false,
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
        .func_names = false,
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
