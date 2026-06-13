const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports @typescript-eslint/no-loop-func for unsafe loop references" {
    const source =
        \\const funcs: Array<() => number> = [];
        \\let count = 0;
        \\for (var i = 0; i < 3; i++) {
        \\  funcs.push(() => i);
        \\}
        \\while (count < 3) {
        \\  count++;
        \\  funcs.push(function () {
        \\    return count;
        \\  });
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_loop_func = false,
        .no_unused_vars = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.typescript_eslint_no_loop_func.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_loop_func.id));
}

test "prefers @typescript-eslint/no-loop-func over core no-loop-func for TypeScript" {
    const source =
        \\const funcs: Array<() => number> = [];
        \\for (var i = 0; i < 3; i++) {
        \\  funcs.push(() => i);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.typescript_eslint_no_loop_func.id));
    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_loop_func.id));
}

test "falls back to core no-loop-func when TypeScript rule is disabled" {
    const source =
        \\const funcs: Array<() => number> = [];
        \\for (var i = 0; i < 3; i++) {
        \\  funcs.push(() => i);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .typescript_eslint_no_loop_func = false,
        .no_unused_vars = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_loop_func.id));
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_loop_func.id));
}

test "does not report @typescript-eslint/no-loop-func for safe loop references" {
    const source =
        \\const funcs: Array<() => number> = [];
        \\const stable = 1;
        \\for (let i = 0; i < 3; i++) {
        \\  let perIteration = i;
        \\  funcs.push(() => perIteration + stable);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_loop_func = false,
        .no_unused_vars = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_loop_func.id));
}

test "can disable @typescript-eslint/no-loop-func" {
    const source =
        \\const funcs: Array<() => number> = [];
        \\for (var i = 0; i < 3; i++) {
        \\  funcs.push(() => i);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_loop_func = false,
        .typescript_eslint_no_loop_func = false,
        .no_unused_vars = false,
        .no_unused_expressions = false,
        .typescript_eslint_no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.typescript_eslint_no_loop_func.id));
}
