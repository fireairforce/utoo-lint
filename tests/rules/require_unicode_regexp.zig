const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports require-unicode-regexp for literals and constructors without unicode flags" {
    const source =
        \\const a = /aaa/;
        \\const b = /bbb/gi;
        \\const c = new RegExp("ccc");
        \\const d = RegExp("ddd", "gi");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.require_unicode_regexp.id));
    try std.testing.expect(hasMessage(result, "Use the 'u' flag."));
}

test "allows require-unicode-regexp when u or v flags are present" {
    const source =
        \\const a = /aaa/u;
        \\const b = /bbb/giv;
        \\const c = new RegExp("ccc", "u");
        \\const d = RegExp("ddd", `giv`);
        \\function local(RegExp) {
        \\  return RegExp("eee");
        \\}
        \\function dynamic(flags) {
        \\  return new RegExp("fff", flags);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.require_unicode_regexp.id));
}

test "supports configured require-unicode-regexp u flag" {
    const source =
        \\const a = /aaa/v;
        \\const b = new RegExp("bbb", "v");
        \\const c = /ccc/u;
        \\const d = new RegExp("ddd", "giu");
    ;

    var options = baseOptions();
    options.require_unicode_regexp_require_flag = .u;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.require_unicode_regexp.id));
}

test "supports configured require-unicode-regexp v flag" {
    const source =
        \\const a = /aaa/u;
        \\const b = new RegExp("bbb", "u");
        \\const c = /ccc/v;
        \\const d = new RegExp("ddd", "giv");
    ;

    var options = baseOptions();
    options.require_unicode_regexp_require_flag = .v;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.require_unicode_regexp.id));
    try std.testing.expect(hasMessage(result, "Use the 'v' flag."));
}

test "can disable require-unicode-regexp" {
    const source =
        \\const a = /aaa/;
        \\const b = new RegExp("bbb");
    ;

    var options = baseOptions();
    options.require_unicode_regexp = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.require_unicode_regexp.id));
}

fn baseOptions() lint.Options {
    return .{
        .no_invalid_regexp = false,
        .no_regex_spaces = false,
        .no_undef = false,
        .no_unused_vars = false,
        .prefer_regex_literals = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.require_unicode_regexp.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
