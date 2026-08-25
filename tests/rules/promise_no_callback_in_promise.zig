const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports callbacks passed to or called inside promise handlers" {
    const source =
        \\a.then(cb);
        \\a.then(() => cb());
        \\a.then(function (error) { callback(error); });
        \\a.then(function (data) { cb(null, data); }, function (error) { cb(error); });
        \\a.catch(function (error) { done(error); });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 6), helpers.countRule(result, lint.rules.promise_no_callback_in_promise.id));
}

test "allows callbacks outside promises and inside deferred handlers" {
    const source =
        \\function thing(cb) { cb(); }
        \\doSomething(error => callback(error));
        \\promise.then(() => process.nextTick(() => cb()));
        \\promise.then(() => setImmediate(() => callback()));
        \\promise.then(() => setTimeout(done));
        \\promise.catch(() => requestAnimationFrame(next));
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_no_callback_in_promise.id));
}

test "supports callback name exceptions" {
    const source =
        \\a.then(next);
        \\a.then(() => next()).catch(error => next(error));
    ;

    var options = ruleOptions();
    try std.testing.expect(options.promise_no_callback_in_promise_exceptions.append("next"));
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_no_callback_in_promise.id));
}

test "timeoutsErr reports callbacks deferred from promise handlers" {
    const source =
        \\promise.then(() => { setTimeout(callback); });
        \\promise.then(() => { setImmediate(() => callback()); });
        \\promise.then(() => process.nextTick(cb));
    ;

    var options = ruleOptions();
    options.promise_no_callback_in_promise_timeouts_err = true;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.promise_no_callback_in_promise.id));
}

test "supports TypeScript promise handlers" {
    const source =
        \\declare const promise: Promise<string>;
        \\declare function callback(error: Error | null, value?: string): void;
        \\promise.then((value: string) => callback(null, value));
        \\function outside(value: string): void { callback(null, value); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.promise_no_callback_in_promise.id));
}

fn ruleOptions() lint.Options {
    var options = lint.Options.allDisabled();
    options.promise_no_callback_in_promise = true;
    return options;
}
