const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports promise/no-return-wrap in promise handlers" {
    const source =
        \\doThing().then(function () { return Promise.resolve(4); });
        \\doThing().then(null, function () { return Promise.reject(4); });
        \\doThing().catch(() => Promise.resolve(4));
        \\doThing().then((function () { return Promise.resolve(4); }).bind(this));
        \\doThing().then(function (x) { if (x) return Promise.reject(x); });
        \\typed.then((value: number): Promise<number> => Promise.resolve(value));
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.promise_no_return_wrap.id));
}

test "allows unwrapped values unrelated functions and other Promise statics" {
    const source =
        \\Promise.resolve(4).then(function (x) { return x; });
        \\doThing().then(function () { return 4; });
        \\doThing().then(function () { throw 4; });
        \\doThing().then(function () { return Promise.all(tasks); });
        \\const fn = function () { return Promise.resolve(4); };
        \\function declared() { return Promise.reject(4); }
        \\doThing(function () { return Promise.resolve(4); });
        \\doThing().then((function () { return Promise.resolve(4); }).toString());
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_no_return_wrap.id));
}

test "supports promise/no-return-wrap allowReject" {
    var config = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "[\"error\",{\"allowReject\":true}]", .{});
    defer config.deinit();
    var options = lint.Options{ .no_undef = false, .parser_semantic_errors = false };
    try options.setByRuleConfigValue("promise/no-return-wrap", config.value);

    const source =
        \\doThing().then(() => Promise.reject(4));
        \\doThing().then(() => Promise.resolve(4));
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.promise_no_return_wrap.id));
}

test "can disable promise/no-return-wrap" {
    const source = "doThing().then(() => Promise.resolve(4));";
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .promise_no_return_wrap = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_no_return_wrap.id));
}
