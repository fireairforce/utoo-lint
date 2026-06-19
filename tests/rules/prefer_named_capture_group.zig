const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports unnamed capture groups in regex literals" {
    const source =
        \\const first = /(foo)/;
        \\const second = /(?:foo)(bar)(?<baz>baz)/;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.prefer_named_capture_group.id));
    try std.testing.expect(hasMessage(result, "Capture group '(foo)' should be converted"));
    try std.testing.expect(hasMessage(result, "Capture group '(bar)' should be converted"));
}

test "does not report named or non-capturing groups" {
    const source =
        \\const named = /(?<name>foo)/;
        \\const nonCapturing = /(?:foo)(?=bar)(?!baz)(?<=qux)(?<!quux)/;
        \\const characterClass = /[(]/;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_named_capture_group.id));
}

test "reports static RegExp constructors and ignores shadowed constructors" {
    const source =
        \\RegExp("(foo)");
        \\new RegExp("(?<name>foo)");
        \\function local(RegExp) {
        \\  RegExp("(bar)");
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.prefer_named_capture_group.id));
}

test "can disable prefer-named-capture-group" {
    const source =
        \\const first = /(foo)/;
    ;

    var options = baseOptions();
    options.prefer_named_capture_group = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_named_capture_group.id));
}

fn baseOptions() lint.Options {
    return .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
        .prefer_named_capture_group = true,
        .prefer_regex_literals = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.prefer_named_capture_group.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
