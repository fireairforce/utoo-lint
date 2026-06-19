const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports constant logical and nullish short-circuiting" {
    const source =
        \\const first = {} || fallback;
        \\const second = [] && fallback;
        \\const third = "value" ?? fallback;
        \\const fourth = null ?? fallback;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_constant_binary_expression.id));
    try std.testing.expect(hasMessage(result, "Unexpected constant truthiness"));
    try std.testing.expect(hasMessage(result, "Unexpected constant nullishness"));
}

test "reports constant nullish and boolean comparisons" {
    const source =
        \\const first = +x == null;
        \\const second = !foo === true;
        \\const third = {} === false;
        \\const fourth = void foo !== null;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_constant_binary_expression.id));
    try std.testing.expect(hasMessage(result, "Unexpected constant binary expression."));
}

test "reports comparisons to newly constructed objects" {
    const source =
        \\const first = value === {};
        \\const second = [] !== value;
        \\const third = {} == [];
        \\const fourth = (condition ? {} : []) === value;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_constant_binary_expression.id));
    try std.testing.expect(hasMessage(result, "Unexpected comparison to newly constructed object."));
    try std.testing.expect(hasMessage(result, "Unexpected comparison of two newly constructed objects."));
}

test "does not report non-constant binary expressions" {
    const source =
        \\const first = value || fallback;
        \\const second = value ?? fallback;
        \\const third = value === other;
        \\const fourth = value == false;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_constant_binary_expression.id));
}

test "can disable no-constant-binary-expression" {
    const source =
        \\const first = {} || fallback;
        \\const second = value === {};
    ;

    var options = baseOptions();
    options.no_constant_binary_expression = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_constant_binary_expression.id));
}

fn baseOptions() lint.Options {
    return .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_constant_binary_expression.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
