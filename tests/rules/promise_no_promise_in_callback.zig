const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports promise/no-promise-in-callback in Node-style callbacks" {
    const source =
        \\load(function (err) { doThing().then(done); });
        \\load(function (error, data) { Promise.all(data); });
        \\load((err) => service.catch(done));
        \\load((error) => Promise.resolve(1));
        \\function declared(err) { Promise.race(tasks); }
        \\const typed = (error: Error | null, value: string) => Promise.reject(error);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.promise_no_promise_in_callback.id));
}

test "allows returned promises non-error callbacks and promise handlers" {
    const source =
        \\load(function (err) { return Promise.resolve(4); });
        \\load(function (err) { return work.then(done); });
        \\load(function (helpers) { work.catch(done); });
        \\load((event) => { Promise.resolve(event); });
        \\work.catch((err) => { next.then(done); });
        \\work.then(function (error) { Promise.all(tasks); });
        \\function ordinary(value) { Promise.resolve(value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_no_promise_in_callback.id));
}

test "supports promise/no-promise-in-callback exemptDeclarations" {
    var config = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        "[\"error\",{\"exemptDeclarations\":true}]",
        .{},
    );
    defer config.deinit();

    var options = lint.Options{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    };
    try options.setByRuleConfigValue("promise/no-promise-in-callback", config.value);

    const source =
        \\function declared(err) { Promise.resolve(err); }
        \\const expression = function (err) { Promise.resolve(err); };
    ;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.promise_no_promise_in_callback.id));
}

test "can disable promise/no-promise-in-callback" {
    const source = "load(function (err) { Promise.resolve(err); });";
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .promise_no_promise_in_callback = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_no_promise_in_callback.id));
}
