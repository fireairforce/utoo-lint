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

test "autofixes a simple binary self update" {
    const source = "value = value + amount;";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings("value += amount;", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.operator_assignment.id));
}

test "autofixes safe left-repeat operators and preserves right-hand text" {
    const source =
        \\value = value - amount;
        \\value = value * amount;
        \\value = value / amount;
        \\value = value % amount;
        \\value = value ** amount;
        \\value = value << amount;
        \\value = value >> amount;
        \\value = value >>> amount;
        \\value = value | mask;
        \\value = value ^ mask;
        \\value = value & mask;
        \\obj.count = obj.count + amount;
        \\this.total = this.total - amount;
        \\obj["count"] = obj["count"] | mask;
        \\obj[0] = obj[0] & mask;
        \\value = (value + amount);
        \\value = value + (amount);
    ;
    const expected =
        \\value -= amount;
        \\value *= amount;
        \\value /= amount;
        \\value %= amount;
        \\value **= amount;
        \\value <<= amount;
        \\value >>= amount;
        \\value >>>= amount;
        \\value |= mask;
        \\value ^= mask;
        \\value &= mask;
        \\obj.count += amount;
        \\this.total -= amount;
        \\obj["count"] |= mask;
        \\obj[0] &= mask;
        \\value += amount;
        \\value += (amount);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .dot_notation = false,
        .eol_last = false,
        .no_bitwise = false,
        .no_undef = false,
        .typescript_eslint_dot_notation = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.operator_assignment.id));
}

test "does not autofix unsafe always-mode diagnostics" {
    const source =
        \\value = amount * value;
        \\obj.deep.count = obj.deep.count + amount;
        \\obj[key] = obj[key] + amount;
        \\value = /* keep */ value + amount;
        \\value = value /* keep */ + amount;
        \\(obj?.count).total = (obj?.count).total + amount;
        \\obj.count = obj?.count + amount;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!result.fixed);
    try std.testing.expectEqualStrings(source, result.output);
    try std.testing.expectEqual(
        @as(usize, 7),
        helpers.countRule(result.result, lint.rules.operator_assignment.id),
    );
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.operator_assignment.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
}

test "always-mode autofix preserves comments outside the removed reference" {
    const source = "obj/* left */.count/* equals */= obj.count +/* right */ amount;";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(
        "obj/* left */.count/* equals */+=/* right */ amount;",
        result.output,
    );
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.operator_assignment.id));
}

test "always-mode autofix preserves trailing comments inside redundant parentheses" {
    const source = "value = ((value + amount /* keep */) /* outer */);";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .capitalized_comments = false,
        .eol_last = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings("value += amount /* keep */ /* outer */;", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.operator_assignment.id));
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

test "autofixes simple shorthand in never mode" {
    const source = "value += amount;";

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .operator_assignment_style = .never,
        .eol_last = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings("value = value + amount;", result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.operator_assignment.id));
}

test "never-mode autofix expands supported shorthand references" {
    const source =
        \\value -= amount;
        \\value *= amount;
        \\value /= amount;
        \\value %= amount;
        \\value **= amount;
        \\value <<= amount;
        \\value >>= amount;
        \\value >>>= amount;
        \\value |= mask;
        \\value ^= mask;
        \\value &= mask;
        \\obj.count += amount;
        \\this.total -= amount;
        \\obj["count"] |= mask;
        \\obj[0] &= mask;
        \\value &&= amount;
        \\value ||= amount;
        \\value ??= amount;
    ;
    const expected =
        \\value = value - amount;
        \\value = value * amount;
        \\value = value / amount;
        \\value = value % amount;
        \\value = value ** amount;
        \\value = value << amount;
        \\value = value >> amount;
        \\value = value >>> amount;
        \\value = value | mask;
        \\value = value ^ mask;
        \\value = value & mask;
        \\obj.count = obj.count + amount;
        \\this.total = this.total - amount;
        \\obj["count"] = obj["count"] | mask;
        \\obj[0] = obj[0] & mask;
        \\value &&= amount;
        \\value ||= amount;
        \\value ??= amount;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .operator_assignment_style = .never,
        .dot_notation = false,
        .eol_last = false,
        .no_bitwise = false,
        .no_undef = false,
        .typescript_eslint_dot_notation = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.operator_assignment.id));
}

test "never-mode autofix preserves right-hand precedence" {
    const source =
        \\value *= amount + 1;
        \\value -= amount - offset;
        \\value += amount + suffix;
        \\value += amount = 1;
        \\value *= (amount + 1);
        \\value += amount * scale;
        \\value **= amount ** exponent;
    ;
    const expected =
        \\value = value * (amount + 1);
        \\value = value - (amount - offset);
        \\value = value + (amount + suffix);
        \\value = value + (amount = 1);
        \\value = value * (amount + 1);
        \\value = value + amount * scale;
        \\value = value ** (amount ** exponent);
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .operator_assignment_style = .never,
        .eol_last = false,
        .no_multi_assign = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.operator_assignment.id));
}

test "never-mode autofix keeps replacement tokens separated" {
    const source =
        \\value+=-amount;
        \\value+=+amount;
        \\value-=--count;
        \\value/=/**/amount;
        \\value/=// keep
        \\amount;
        \\value/=/pattern/;
        \\value+=/**/+amount;
        \\value+= +amount;
    ;
    const expected =
        \\value= value+-amount;
        \\value= value+ +amount;
        \\value= value- --count;
        \\value= value/ /**/amount;
        \\value= value/ // keep
        \\amount;
        \\value= value/ /pattern/;
        \\value= value+/**/+amount;
        \\value= value+ +amount;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .operator_assignment_style = .never,
        .capitalized_comments = false,
        .eol_last = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.operator_assignment.id));
}

test "never-mode autofix preserves comments after the operator" {
    const source =
        \\value +=/* keep */ amount;
        \\value +=// keep
        \\ amount;
    ;
    const expected =
        \\value = value +/* keep */ amount;
        \\value = value +// keep
        \\ amount;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .operator_assignment_style = .never,
        .capitalized_comments = false,
        .eol_last = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.operator_assignment.id));
}

test "does not autofix never-mode references that would be duplicated unsafely" {
    const source =
        \\value/* keep */+= amount;
        \\obj/* keep */.count += amount;
        \\(/* keep */value) += amount;
        \\obj.deep.count += amount;
        \\obj[key] += amount;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .operator_assignment_style = .never,
        .capitalized_comments = false,
        .eol_last = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!result.fixed);
    try std.testing.expectEqualStrings(source, result.output);
    try std.testing.expectEqual(
        @as(usize, 5),
        helpers.countRule(result.result, lint.rules.operator_assignment.id),
    );
    for (result.result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.operator_assignment.id)) {
            try std.testing.expectEqual(@as(usize, 0), diagnostic.fixes.len);
        }
    }
}

test "never-mode autofix preserves parentheses and comments outside the assignment" {
    const source =
        \\(/* outside */value += amount);
        \\(obj.count) ^= mask;
    ;
    const expected =
        \\(/* outside */value = value + amount);
        \\(obj.count) = (obj.count) ^ mask;
    ;

    var result = try lint.lintSourceAndFix(std.testing.allocator, source, "fixture.js", .{
        .operator_assignment_style = .never,
        .capitalized_comments = false,
        .eol_last = false,
        .no_bitwise = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.fixed);
    try std.testing.expectEqualStrings(expected, result.output);
    try std.testing.expect(!helpers.hasRule(result.result, lint.rules.operator_assignment.id));
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
