const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

const base_options = lint.Options{
    .no_unmodified_loop_condition = true,
    .no_undef = false,
    .no_unused_vars = false,
    .parser_semantic_errors = false,
};

test "accepts official ESLint valid cases" {
    const cases = [_][]const u8{
        "var foo = 0; while (foo) { ++foo; }",
        "let foo = 0; while (foo) { ++foo; }",
        "var foo = 0; while (foo) { foo += 1; }",
        "var foo = 0; while (foo++) { }",
        "var foo = 0; while (foo = next()) { }",
        "var foo = 0; while (ok(foo)) { }",
        "var foo = 0, bar = 0; while (++foo < bar) { }",
        "var foo = 0, obj = {}; while (foo === obj.bar) { }",
        "var foo = 0, f = {}, bar = {}; while (foo === f(bar)) { }",
        "var foo = 0, f = {}; while (foo === f()) { }",
        "var foo = 0, tag = 0; while (foo === tag`abc`) { }",
        "function* f() { var foo = 0; while (yield foo) { } }",
        "function* f() { var foo = 0; while (foo === (yield)) { } }",
        "var foo = 0; while (foo.ok) { }",
        "var foo = 0; while (foo) { update(); } function update() { ++foo; }",
        "var foo = 0, bar = 9; while (foo < bar) { foo += 1; }",
        "var foo = 0, bar = 1, baz = 2; while (foo ? bar : baz) { foo += 1; }",
        "var foo = 0, bar = 0; while (foo && bar) { ++foo; ++bar; }",
        "var foo = 0, bar = 0; while (foo || bar) { ++foo; ++bar; }",
        "var foo = 0; do { ++foo; } while (foo);",
        "var foo = 0; do { } while (foo++);",
        "for (var foo = 0; foo; ++foo) { }",
        "for (var foo = 0; foo;) { ++foo }",
        "var foo = 0, bar = 0; for (bar; foo;) { ++foo }",
        "var foo; if (foo) { }",
        "var a = [1, 2, 3]; var len = a.length; for (var i = 0; i < len - 1; i++) {}",
        "var foo; while (foo) { var [foo] = values; }",
    };

    for (cases) |source| {
        var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", base_options);
        defer result.deinit(std.testing.allocator);
        try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unmodified_loop_condition.id));
    }
}

test "reports official ESLint invalid cases" {
    const Case = struct { source: []const u8, count: usize };
    const cases = [_]Case{
        .{ .source = "var foo = 0; while (foo) { } foo = 1;", .count = 1 },
        .{ .source = "var foo = 0; while (!foo) { } foo = 1;", .count = 1 },
        .{ .source = "var foo = 0; while (foo != null) { } foo = 1;", .count = 1 },
        .{ .source = "var foo = 0, bar = 9; while (foo < bar) { } foo = 1;", .count = 2 },
        .{ .source = "var foo = 0, bar = 0; while (foo && bar) { ++bar; } foo = 1;", .count = 1 },
        .{ .source = "var foo = 0, bar = 0; while (foo && bar) { ++foo; } foo = 1;", .count = 1 },
        .{ .source = "var a, b, c; while (a < c && b < c) { ++a; } foo = 1;", .count = 2 },
        .{ .source = "var foo = 0; while (foo ? 1 : 0) { } foo = 1;", .count = 1 },
        .{ .source = "var foo = 0; while (foo) { update(); } function update(foo) { ++foo; }", .count = 1 },
        .{ .source = "var foo; do { } while (foo);", .count = 1 },
        .{ .source = "for (var foo = 0; foo < 10; ) { } foo = 1;", .count = 1 },
    };

    for (cases) |case| {
        var result = try lint.lintSource(std.testing.allocator, case.source, "fixture.js", base_options);
        defer result.deinit(std.testing.allocator);
        try std.testing.expectEqual(case.count, helpers.countRule(result, lint.rules.no_unmodified_loop_condition.id));
    }
}

test "uses the official message and supports configuration" {
    var result = try lint.lintSource(
        std.testing.allocator,
        "var foo; while (foo) {}",
        "fixture.js",
        base_options,
    );
    defer result.deinit(std.testing.allocator);

    var found = false;
    for (result.diagnostics) |diagnostic| {
        if (!std.mem.eql(u8, diagnostic.rule_id, lint.rules.no_unmodified_loop_condition.id)) continue;
        try std.testing.expectEqualStrings("'foo' is not modified in this loop.", diagnostic.message);
        found = true;
    }
    try std.testing.expect(found);

    var options = lint.Options{};
    try options.setByRuleConfigValue("no-unmodified-loop-condition", .{ .string = "error" });
    try std.testing.expect(options.no_unmodified_loop_condition);
}

test "is disabled by default" {
    var result = try lint.lintSource(std.testing.allocator, "var foo; while (foo) {}", "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_unmodified_loop_condition.id));
}
