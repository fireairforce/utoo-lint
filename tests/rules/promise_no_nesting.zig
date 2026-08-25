const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports then and catch calls nested in promise handlers" {
    const source =
        \\doThing().then(function () { a.then(); });
        \\doThing().then(function () { return b.catch(); });
        \\doThing().then(() => { a.then(); });
        \\doThing().then(() => b.catch());
        \\doThing().catch(() => a.then());
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.promise_no_nesting.id));
}

test "allows flat chains and Promise static calls inside handlers" {
    const source =
        \\promise.then(first).then(second).catch(recover);
        \\Promise.resolve(4).then(value => value);
        \\Promise.reject(4).catch(recover);
        \\doThing().then(() => Promise.resolve(4));
        \\doThing().then(() => Promise.all([a, b, c]));
        \\function load() { return Promise.resolve(4); }
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_no_nesting.id));
}

test "allows nesting whose callback closes over the closest promise handler" {
    const source =
        \\doThing().then(a => getB(a).then(b => getC(a, b)));
        \\doThing().then(a => { const c = a * 2; return getB(c).then(b => getC(c, b)); });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_no_nesting.id));
}

test "reports nesting without a closest-handler closure reference" {
    const source =
        \\doThing().then(a => getB(a).then(b => getC(b)));
        \\doThing().then(a => getB(a).then(b => getC(a, b).then(c => getD(a, c))));
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.promise_no_nesting.id));
}

test "supports TypeScript nested promise handlers" {
    const source =
        \\declare function getValue(): Promise<number>;
        \\declare function getNext(value: number): Promise<string>;
        \\getValue().then((value: number) => getNext(value).then((next: string) => next.length));
        \\getValue().then((value: number) => getNext(value).then((next: string) => `${value}:${next}`));
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.promise_no_nesting.id));
}

fn ruleOptions() lint.Options {
    var options = lint.Options.allDisabled();
    options.promise_no_nesting = true;
    return options;
}
