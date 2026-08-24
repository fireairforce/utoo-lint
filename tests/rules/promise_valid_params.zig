const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports promise/valid-params for invalid argument counts" {
    const source =
        \\Promise.resolve(1, 2);
        \\Promise.reject(1, 2, 3);
        \\Promise.all();
        \\Promise.race(one, two);
        \\Promise.allSettled(one, two);
        \\Promise.any();
        \\somePromise().then();
        \\somePromise().then(one, two, three);
        \\promise.catch();
        \\promise.finally(one, two);
        \\typed.then((value: number) => value, onError, extra);
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 11), helpers.countRule(result, lint.rules.promise_valid_params.id));
}

test "allows valid Promise method argument counts" {
    const source =
        \\Promise.resolve();
        \\Promise.resolve(value);
        \\Promise.reject();
        \\Promise.reject(error);
        \\Promise.all(items);
        \\Promise.race(items);
        \\Promise.allSettled(items);
        \\Promise.any(items);
        \\promise.then(success);
        \\promise.then(success, failure);
        \\promise.catch(failure);
        \\promise.finally(done);
        \\Promise.withResolvers();
        \\object.resolve(one, two);
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_valid_params.id));
}

test "supports promise/valid-params exclude" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"exclude\":[\"catch\",\"resolve\"]}]",
        .{},
    );
    defer config.deinit();
    var options = lint.Options{ .no_undef = false, .parser_semantic_errors = false };
    try options.setByRuleConfigValue("promise/valid-params", config.value);

    const source =
        \\Promise.resolve(one, two);
        \\promise.catch(one, two);
        \\promise.finally(one, two);
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.promise_valid_params.id));
}

test "can disable promise/valid-params" {
    const source = "Promise.all();";
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .promise_valid_params = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_valid_params.id));
}
