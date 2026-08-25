const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports promise/param-names for nonstandard executor parameters" {
    const source =
        \\new Promise(function (reject, resolve) {});
        \\new Promise((yes, no) => {});
        \\new Promise((ok: (value: number) => void, fail: (error: Error) => void) => {});
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_new = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.promise_param_names.id));
}

test "allows conventional Promise executor parameter names" {
    const source =
        \\new Promise(function (resolve, reject) {});
        \\new Promise(function (_resolve, _reject) {});
        \\new Promise(resolve => {});
        \\new Promise(() => {});
        \\new NonPromise((yes, no) => {});
        \\new Promise(namedExecutor);
        \\new Promise((resolve, reject) => {}, extra);
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_param_names.id));
}

test "supports custom promise/param-names patterns" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"resolvePattern\":\"^yes$\",\"rejectPattern\":\"^no$\"}]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{ .no_new = false, .no_undef = false, .no_unused_vars = false, .parser_semantic_errors = false };
    try options.setByRuleConfigValue("promise/param-names", config.value);

    const source =
        \\new Promise((yes, no) => {});
        \\new Promise((resolve, reject) => {});
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.promise_param_names.id));
}

test "can disable promise/param-names" {
    const source = "new Promise((yes, no) => {});";
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .promise_param_names = false,
        .no_new = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_param_names.id));
}
