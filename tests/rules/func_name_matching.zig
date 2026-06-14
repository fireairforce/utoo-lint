const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports func-name-matching for mismatched variable and assignment targets" {
    const source =
        \\const first = function second() {};
        \\let third;
        \\third = function fourth() {};
        \\object.value = function other() {};
        \\this.ready = function done() {};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .func_names = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.func_name_matching.id));
    try std.testing.expectEqualStrings(
        "Function name `second` should match target name `first`.",
        result.diagnostics[0].message,
    );
}

test "reports func-name-matching for mismatched object and class fields" {
    const source =
        \\const object = {
        \\  value: function other() {},
        \\  ["computed"]: function otherComputed() {},
        \\};
        \\class Example {
        \\  field = function otherField() {};
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .func_names = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.func_name_matching.id));
}

test "does not report func-name-matching for matching or unsupported cases" {
    const source =
        \\const first = function first() {};
        \\const unnamed = function () {};
        \\const arrow = () => {};
        \\object.value = function value() {};
        \\object[getName()] = function dynamic() {};
        \\module.exports = function exported() {};
        \\exports.value = function exportedValue() {};
        \\const object = {
        \\  method() {},
        \\  value: function value() {},
        \\};
        \\class Example {
        \\  field = function field() {};
        \\  #private = function other() {};
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .func_names = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.func_name_matching.id));
}

test "reports func-name-matching for matching names in never mode" {
    const source =
        \\const first = function first() {};
        \\object.value = function value() {};
        \\const object = {
        \\  prop: function prop() {},
        \\};
        \\class Example {
        \\  field = function field() {};
        \\}
        \\const mismatch = function other() {};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .func_name_matching_style = .never,
        .func_names = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.func_name_matching.id));
    try std.testing.expectEqualStrings(
        "Function name `first` should not match target name `first`.",
        result.diagnostics[0].message,
    );
}

test "can disable func-name-matching" {
    const source =
        \\const first = function second() {};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .func_name_matching = false,
        .func_names = false,
        .no_empty_function = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.func_name_matching.id));
}
