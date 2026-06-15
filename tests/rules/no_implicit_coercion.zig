const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-implicit-coercion for boolean coercion" {
    const source =
        \\const first = !!value;
        \\const second = ~items.indexOf(value);
        \\const third = ~items.lastIndexOf(value);
        \\const fourth = ~items[`indexOf`](value);
        \\const fifth = ~items[`lastIndexOf`](value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_implicit_coercion.id));
    try std.testing.expectEqualStrings("Use `Boolean()` instead of double negation.", result.diagnostics[0].message);
}

test "reports no-implicit-coercion for number coercion" {
    const source =
        \\const first = +value;
        \\const second = -(-value);
        \\const third = value - 0;
        \\const fourth = value * 1;
        \\const fifth = 1 * value;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_implicit_coercion.id));
}

test "reports no-implicit-coercion for string coercion" {
    const source =
        \\const first = "" + value;
        \\const second = value + "";
        \\let third = value;
        \\third += "";
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_implicit_coercion.id));
}

test "does not report no-implicit-coercion for explicit conversions" {
    const source =
        \\const first = Boolean(value);
        \\const second = items.indexOf(value) !== -1;
        \\const third = Number(value);
        \\const fourth = String(value);
        \\const fifth = `${value}`;
        \\const sixth = +1;
        \\const seventh = -(-1);
        \\const eighth = 1 - 0;
        \\const ninth = 1 * Number(value);
        \\const tenth = "" + "value";
        \\const eleventh = `value` + "";
        \\const twelfth = ~items[`index${suffix}`](value);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_implicit_coercion.id));
}

test "supports no-implicit-coercion category options" {
    const source =
        \\const first = !!value;
        \\const second = ~items.indexOf(value);
        \\const third = +value;
        \\const fourth = value - 0;
        \\const fifth = "" + value;
        \\let sixth = value;
        \\sixth += "";
    ;

    var boolean_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_implicit_coercion_boolean = .no,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer boolean_result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(boolean_result, lint.rules.no_implicit_coercion.id));

    var number_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_implicit_coercion_number = .no,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer number_result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(number_result, lint.rules.no_implicit_coercion.id));

    var string_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_implicit_coercion_string = .no,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer string_result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(string_result, lint.rules.no_implicit_coercion.id));

    var all_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_implicit_coercion_boolean = .no,
        .no_implicit_coercion_number = .no,
        .no_implicit_coercion_string = .no,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer all_result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(all_result, lint.rules.no_implicit_coercion.id));
}

test "can disable no-implicit-coercion" {
    const source =
        \\const first = !!value;
        \\const second = +value;
        \\const third = "" + value;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_implicit_coercion = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_implicit_coercion.id));
}
