const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports unexpected aliases for this" {
    const source =
        \\const self = this;
        \\let that = this;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.consistent_this.id));
    try std.testing.expect(hasMessage(result, "Unexpected alias 'self' for 'this'."));
}

test "reports configured aliases assigned to non-this values" {
    const source =
        \\const that = window;
        \\that += this;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.consistent_this.id));
    try std.testing.expect(hasMessage(result, "Designated alias 'that' is not assigned to 'this'."));
}

test "allows deferred same-scope assignment to this" {
    const source =
        \\let that;
        \\that = this;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.consistent_this.id));
}

test "reports configured aliases not assigned to this in their scope" {
    const source =
        \\function run() {
        \\  let that;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", baseOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.consistent_this.id));
}

test "supports configured aliases from eslint config" {
    const source =
        \\const that = this;
        \\const self = this;
        \\const context = this;
    ;

    var options = baseOptions();
    var parsed = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\", \"self\", \"context\"]",
        .{},
    );
    defer parsed.deinit();
    try options.setByRuleConfigValue("consistent-this", parsed.value);

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.consistent_this.id));
    try std.testing.expect(hasMessage(result, "Unexpected alias 'that' for 'this'."));
}

test "can disable consistent-this" {
    const source =
        \\const self = this;
    ;

    var options = baseOptions();
    options.consistent_this = false;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.consistent_this.id));
}

fn baseOptions() lint.Options {
    return .{
        .consistent_this = true,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
}

fn hasMessage(result: lint.Result, needle: []const u8) bool {
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.consistent_this.id)) continue;
        if (std.mem.indexOf(u8, diagnostic.message, needle) != null) return true;
    }
    return false;
}
