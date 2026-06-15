const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports logical-assignment-operators for self logical assignments" {
    const source =
        \\let first;
        \\let second;
        \\let third;
        \\first = first || fallback;
        \\second = second && fallback;
        \\third = third ?? fallback;
        \\object.value = object.value || fallback;
        \\this.ready = this.ready && fallback;
        \\object[`value`] = object[`value`] || fallback;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.logical_assignment_operators.id));
}

test "reports logical-assignment-operators for short-circuit assignment expressions" {
    const source =
        \\let first;
        \\let second;
        \\let third;
        \\first || (first = fallback);
        \\second && (second = fallback);
        \\third ?? (third = fallback);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_unused_expressions = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.logical_assignment_operators.id));
    try std.testing.expectEqualStrings("Assignment can be replaced with `||=`.", result.diagnostics[0].message);
}

test "reports logical-assignment-operators for if statements when enabled" {
    const source =
        \\if (first) first = fallback;
        \\if (!second) {
        \\  second = fallback;
        \\}
        \\if (third == null) third = fallback;
        \\if (null == fourth) fourth = fallback;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .curly = false,
        .eol_last = false,
        .logical_assignment_operators_enforce_for_if_statements = .yes,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.logical_assignment_operators.id));
    try std.testing.expectEqualStrings("Assignment can be replaced with `&&=`.", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("Assignment can be replaced with `||=`.", result.diagnostics[1].message);
    try std.testing.expectEqualStrings("Assignment can be replaced with `??=`.", result.diagnostics[2].message);
}

test "does not report logical-assignment-operators for if statements by default" {
    const source =
        \\if (value) value = fallback;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .curly = false,
        .eol_last = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.logical_assignment_operators.id));
}

test "does not report logical-assignment-operators when shorthand would change meaning" {
    const source =
        \\let value;
        \\value = fallback || value;
        \\value = value + fallback;
        \\value ||= fallback;
        \\value || (other = fallback);
        \\object[getKey()] = object[getKey()] || fallback;
        \\object[`val${suffix}`] = object[`val${suffix}`] || fallback;
        \\object.value = other.value || fallback;
        \\if (value) other = fallback;
        \\if (value != null) value = fallback;
        \\if (value === null) value = fallback;
        \\if (value) {
        \\  value = fallback;
        \\  other = fallback;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .curly = false,
        .logical_assignment_operators_enforce_for_if_statements = .yes,
        .no_unused_expressions = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.logical_assignment_operators.id));
}

test "reports logical-assignment-operators for logical assignments in never mode" {
    const source =
        \\first ||= fallback;
        \\second &&= fallback;
        \\third ??= fallback;
        \\fourth = fourth || fallback;
        \\fourth || (fourth = fallback);
        \\if (fourth) fourth = fallback;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .curly = false,
        .eol_last = false,
        .logical_assignment_operators_style = .never,
        .logical_assignment_operators_enforce_for_if_statements = .yes,
        .no_unused_expressions = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.logical_assignment_operators.id));
    try std.testing.expectEqualStrings("Unexpected logical assignment operator `||=`.", result.diagnostics[0].message);
    try std.testing.expectEqualStrings("Unexpected logical assignment operator `&&=`.", result.diagnostics[1].message);
    try std.testing.expectEqualStrings("Unexpected logical assignment operator `??=`.", result.diagnostics[2].message);
}

test "can disable logical-assignment-operators" {
    const source =
        \\let value;
        \\value = value || fallback;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .logical_assignment_operators = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.logical_assignment_operators.id));
}
