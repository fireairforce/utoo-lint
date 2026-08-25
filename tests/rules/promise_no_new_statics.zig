const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports and autofixes construction of Promise static methods" {
    const source =
        \\new Promise.resolve();
        \\new Promise.reject();
        \\new Promise.all([]);
        \\new Promise.allSettled([]);
        \\new Promise.any([]);
        \\new Promise.race([]);
        \\new Promise.withResolvers();
    ;
    const expected =
        \\Promise.resolve();
        \\Promise.reject();
        \\Promise.all([]);
        \\Promise.allSettled([]);
        \\Promise.any([]);
        \\Promise.race([]);
        \\Promise.withResolvers();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.promise_no_new_statics.id));
    var fixed = try lint.applyFixes(std.testing.allocator, source, result.diagnostics);
    defer fixed.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(expected, fixed.output);
}

test "allows ordinary Promise calls and non-Promise constructors" {
    const source =
        \\Promise.resolve();
        \\Promise.reject();
        \\Promise.all([]);
        \\Promise.race([]);
        \\new Promise(resolve => resolve());
        \\new SomeClass();
        \\new SomeClass.resolve();
        \\new Promise["resolve"]();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_no_new_statics.id));
}

test "matches syntactic Promise names and computed identifiers" {
    const source =
        \\function local(Promise, resolve) {
        \\  new Promise.resolve();
        \\  new Promise[resolve]();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.promise_no_new_statics.id));
}

test "supports TypeScript Promise static construction" {
    const source =
        \\const value = new Promise.resolve<number>(1);
        \\const valid = Promise.resolve<number>(1);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", ruleOptions());
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.promise_no_new_statics.id));
}

fn ruleOptions() lint.Options {
    var options = lint.Options.allDisabled();
    options.promise_no_new_statics = true;
    return options;
}
