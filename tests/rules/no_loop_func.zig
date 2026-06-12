const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-loop-func for functions with unsafe loop references" {
    const source =
        \\var funcs = [];
        \\var count = 0;
        \\var flag = true;
        \\for (var i = 0; i < 3; i++) {
        \\  funcs.push(function() {
        \\    return i;
        \\  });
        \\}
        \\while (flag) {
        \\  count++;
        \\  funcs.push(() => count);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_loop_func.id));
}

test "reports no-loop-func for for-in and for-of iteration variables" {
    const source =
        \\var funcs = [];
        \\var obj = {};
        \\var list = [];
        \\for (var key in obj) {
        \\  funcs.push(() => key);
        \\}
        \\for (var item of list) {
        \\  funcs.push(function() {
        \\    return item;
        \\  });
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_loop_func.id));
}

test "does not report no-loop-func for per-iteration bindings or stable values" {
    const source =
        \\var funcs = [];
        \\const stable = 1;
        \\for (let i = 0; i < 3; i++) {
        \\  let perIteration = i;
        \\  funcs.push(() => perIteration + stable);
        \\}
        \\function outer() {
        \\  for (var j = 0; j < 3; j++) {}
        \\  return () => stable;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_loop_func.id));
}

test "can disable no-loop-func" {
    const source =
        \\var funcs = [];
        \\for (var i = 0; i < 3; i++) {
        \\  funcs.push(() => i);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_loop_func = false,
        .no_unused_vars = false,
        .no_unused_expressions = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_loop_func.id));
}
