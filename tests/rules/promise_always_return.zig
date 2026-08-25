const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports promise/always-return callbacks that can fall through" {
    const source =
        \\promise.then(value => {});
        \\promise.then(function () { consume(); });
        \\promise.then(value => { if (value) return value; });
        \\promise.then(value => {}).then(value => {});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.promise_always_return.id));
}

test "allows promise/always-return callbacks with terminal paths" {
    const source =
        \\promise.then(value => value * 2);
        \\promise.then(handler);
        \\promise.then(value => { return; });
        \\promise.then(value => { if (value) return value; throw new Error("missing"); });
        \\promise.then(value => { if (value) process.exit(0); else process.abort(); });
        \\promise.then(value => { switch (value) { case 1: return value; default: throw new Error(); } });
        \\promise.then(value => { try { return value; } catch (error) { throw error; } });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_always_return.id));
}

test "reports switch callbacks that break or omit a default path" {
    const source =
        \\promise.then(value => { switch (value) { case 1: break; default: return value; } });
        \\promise.then(value => { switch (value) { case 1: return value; } });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.promise_always_return.id));
}

test "supports promise/always-return ignoreLastCallback chain handling" {
    const source =
        \\promise.then(value => { consume(value); });
        \\void promise.then(value => { consume(value); });
        \\promise.then(value => { consume(value); }).then(value => { consume(value); });
        \\const assigned = promise.then(value => { consume(value); });
        \\function returned() { return promise.then(value => { consume(value); }); }
        \\async function awaited() { return await promise.then(value => { consume(value); }); }
        \\async function consumed() { await promise.then(value => { consume(value); }); }
    ;

    var options = ruleOptions();
    options.promise_always_return_ignore_last_callback = true;
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", options);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.promise_always_return.id));
}

test "supports promise/always-return ignored assignment variables" {
    const source =
        \\promise.then(value => { globalThis = value; });
        \\promise.then(value => { globalThis.result.value = value; });
        \\promise.then(value => { other.result = value; });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.promise_always_return.id));

    var options = ruleOptions();
    options.promise_always_return_ignore_assignment_variables.custom = true;
    try std.testing.expect(options.promise_always_return_ignore_assignment_variables.append("window"));
    const custom_source =
        \\promise.then(value => { window.result = value; });
        \\promise.then(value => { globalThis.result = value; });
        \\promise.then(value => { windows.result = value; });
    ;
    var custom_result = try lint.lintSource(std.testing.allocator, custom_source, "fixture.js", options);
    defer custom_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(custom_result, lint.rules.promise_always_return.id));
}

test "supports TypeScript promise/always-return callbacks" {
    const source =
        \\declare const promise: Promise<string>;
        \\promise.then((value: string) => { consume(value); });
        \\promise.then((value: string): number => value.length);
        \\promise.then(function (value: string): number { return value.length; });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.promise_always_return.id));
}

fn ruleOptions() lint.Options {
    var options = lint.Options.allDisabled();
    options.promise_always_return = true;
    return options;
}
