const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports operator-assignment for assignable binary self updates" {
    const source =
        \\let value = 1;
        \\value = value + amount;
        \\value = value - amount;
        \\value = value * amount;
        \\value = value / amount;
        \\value = value % amount;
        \\value = value ** amount;
        \\value = value << amount;
        \\value = value >>> amount;
        \\obj.count = obj.count + amount;
        \\this.total = this.total - amount;
        \\obj["count"] = obj["count"] | mask;
        \\obj[0] = obj[0] & mask;
        \\value = amount * value;
        \\value = amount | value;
        \\value = amount ^ value;
        \\value = amount & value;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_bitwise = false,
        .no_multi_assign = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 16), helpers.countRule(result, lint.rules.operator_assignment.id));
}

test "does not report operator-assignment when shorthand would change the expression" {
    const source =
        \\let value = 1;
        \\value = amount + value;
        \\value = amount - value;
        \\value = value && amount;
        \\value = value < amount;
        \\value += amount;
        \\obj.count = other.count + amount;
        \\obj[getKey()] = obj[getKey()] + amount;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_bitwise = false,
        .no_multi_assign = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.operator_assignment.id));
}

test "reports operator-assignment for shorthand when configured never" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",\"never\"]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_bitwise = false,
        .no_multi_assign = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("operator-assignment", config.value);

    const source =
        \\value += amount;
        \\value -= amount;
        \\value *= amount;
        \\value /= amount;
        \\value %= amount;
        \\value **= amount;
        \\value <<= amount;
        \\value >>= amount;
        \\value >>>= amount;
        \\value |= amount;
        \\value ^= amount;
        \\value &= amount;
        \\value = value + amount;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 12), helpers.countRule(result, lint.rules.operator_assignment.id));
}

test "can disable operator-assignment" {
    const source =
        \\let value = 1;
        \\value = value + amount;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .operator_assignment = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.operator_assignment.id));
}
