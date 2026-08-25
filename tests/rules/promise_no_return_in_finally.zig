const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports promise/no-return-in-finally for top-level callback returns" {
    const source =
        \\Promise.resolve(1).finally(() => { return 2; });
        \\Promise.reject(0).finally(function () { return 2; });
        \\myPromise.finally(() => { return value; });
        \\typed.finally((): number => { return 3; });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.promise_no_return_in_finally.id));
}

test "allows finally callbacks without a top-level return" {
    const source =
        \\Promise.resolve(1).finally(() => { console.log(2); });
        \\Promise.reject(4).finally(() => {});
        \\myPromise.finally(function () {});
        \\myPromise.finally(() => value);
        \\myPromise.finally(() => { if (ready) return value; });
        \\myPromise.finally(() => { function nested() { return value; } });
        \\myPromise.then(() => { return value; });
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_no_return_in_finally.id));
}

test "can disable promise/no-return-in-finally" {
    const source = "promise.finally(() => { return value; });";
    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .promise_no_return_in_finally = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.promise_no_return_in_finally.id));
}
