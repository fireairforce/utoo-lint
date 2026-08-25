const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports unterminated promise chains" {
    const source =
        \\promise.then(handle);
        \\fetch(url).then(log);
        \\Promise.resolve(value);
        \\Promise.all(values);
        \\promise.then(handle).catch(recover).then(next);
        \\promise.then(handle).finally(cleanup);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.promise_catch_or_return.id));
}

test "allows caught, returned, Cypress, and non-promise expressions" {
    const source =
        \\promise.then(handle).catch(recover);
        \\Promise.resolve(value)["catch"](recover);
        \\function load() { return promise.then(handle); }
        \\const assigned = promise.then(handle);
        \\await promise.then(handle);
        \\cy.get("button").click().then(handle);
        \\nonPromiseCall();
        \\Promise.withResolvers();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.mjs", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_catch_or_return.id));
}

test "supports allowThen and allowThenStrict" {
    const source =
        \\promise.then(handle, recover);
        \\promise.then(null, recover);
    ;

    var default_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer default_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(default_result, lint.rules.promise_catch_or_return.id));

    var allow_then = ruleOptions();
    allow_then.promise_catch_or_return_allow_then = true;
    var allow_then_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", allow_then);
    defer allow_then_result.deinit(std.testing.allocator);
    try std.testing.expect(!helpers.hasRule(allow_then_result, lint.rules.promise_catch_or_return.id));

    var strict = ruleOptions();
    strict.promise_catch_or_return_allow_then_strict = true;
    var strict_result = try lint.lintSource(std.testing.allocator, source, "fixture.js", strict);
    defer strict_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(strict_result, lint.rules.promise_catch_or_return.id));
}

test "supports allowFinally only after an allowed rejection handler" {
    const source =
        \\promise.then(handle).catch(recover).finally(cleanup);
        \\promise.then(handle).finally(cleanup);
        \\promise.then(handle).catch(recover).finally(cleanup).then(next);
    ;

    var options = ruleOptions();
    options.promise_catch_or_return_allow_finally = true;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.promise_catch_or_return.id));
}

test "supports custom promise termination methods" {
    const source =
        \\promise.then(handle).done();
        \\promise.then(handle).catch(recover);
    ;

    var options = ruleOptions();
    options.promise_catch_or_return_termination_methods.custom = true;
    try std.testing.expect(options.promise_catch_or_return_termination_methods.append("done"));
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.promise_catch_or_return.id));
    for (result.diagnostics) |diagnostic| {
        if (std.mem.eql(u8, diagnostic.rule_id, lint.rules.promise_catch_or_return.id)) {
            try std.testing.expectEqualStrings("Expected done() or return", diagnostic.message);
        }
    }
}

test "supports TypeScript promise chains" {
    const source =
        \\declare const promise: Promise<string>;
        \\promise.then((value: string) => value.length);
        \\function load(): Promise<number> { return promise.then((value: string) => value.length); }
        \\promise.then((value: string) => value.length).catch(recover);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.promise_catch_or_return.id));
}

fn ruleOptions() lint.Options {
    var options = lint.Options.allDisabled();
    options.promise_catch_or_return = true;
    return options;
}
