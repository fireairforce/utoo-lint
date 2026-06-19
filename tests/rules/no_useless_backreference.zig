const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-useless-backreference for nested and forward references" {
    const source =
        \\const nested = /((a)\1)/;
        \\const forward = /\1(a)/;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_useless_backreference.id));
    try std.testing.expect(hasMessage(result, "from within that group"));
    try std.testing.expect(hasMessage(result, "which appears later in the pattern"));
}

test "reports no-useless-backreference across alternatives and negative lookaround" {
    const source =
        \\const disjunctive = /(a)|\1/;
        \\const negative = /(?!(a))\1/;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_useless_backreference.id));
    try std.testing.expect(hasMessage(result, "which is in another alternative"));
    try std.testing.expect(hasMessage(result, "which is in a negative lookaround"));
}

test "does not report useful backreferences" {
    const source =
        \\const simple = /(a)\1/;
        \\const named = /(?<word>a)\1/;
        \\const missing = /(a)\2/;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_backreference.id));
}

test "reports no-useless-backreference for static RegExp constructors" {
    const source =
        \\RegExp("\\1(a)");
        \\new RegExp("(a)|\\1");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_useless_backreference.id));
}

test "does not report shadowed or dynamic RegExp constructors" {
    const source =
        \\function local(RegExp, pattern) {
        \\  RegExp("\\1(a)");
        \\  new RegExp(pattern);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_backreference.id));
}

test "can disable no-useless-backreference" {
    const source =
        \\const forward = /\1(a)/;
    ;

    var options = baseOptions();
    options.no_useless_backreference = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_backreference.id));
}

fn baseOptions() lint.Options {
    return .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .prefer_regex_literals = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_useless_backreference.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
