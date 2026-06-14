const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports prefer-const for initialized let declarations that are never reassigned" {
    const source =
        \\let a = 1;
        \\let { b } = obj;
        \\let [c] = list;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.prefer_const.id));
}

test "does not report prefer-const for reassigned let bindings or uninitialized declarations" {
    const source =
        \\let a = 1;
        \\a = 2;
        \\let b = 1;
        \\b++;
        \\let c;
        \\c = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_const.id));
}

test "reports prefer-const for destructuring any by default" {
    const source =
        \\let { a, b } = obj;
        \\b = 2;
        \\let [c, d] = list;
        \\d++;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.prefer_const.id));
}

test "reports prefer-const for destructuring only when all bindings qualify in all mode" {
    const source =
        \\let { a, b } = obj;
        \\b = 2;
        \\let [c, d] = list;
        \\let { e: { f }, ...rest } = other;
        \\rest = {};
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .prefer_const_destructuring = .all,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.prefer_const.id));
}

test "can disable prefer-const" {
    const source =
        \\let a = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .prefer_const = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_const.id));
}
