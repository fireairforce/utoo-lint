const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports prefer-promise-reject-errors for obvious non-error rejection reasons" {
    const source =
        \\const suffix = "ject";
        \\Promise.reject("failed");
        \\Promise["reject"]("failed");
        \\Promise[`reject`]("failed");
        \\Promise.reject?.("failed");
        \\Promise?.reject("failed");
        \\Promise?.["reject"]("failed");
        \\Promise?.[`reject`]("failed");
        \\Promise[`re${suffix}`]("dynamic");
        \\Promise.reject(1);
        \\Promise.reject(`failed`);
        \\Promise.reject(undefined);
        \\Promise.reject("failed " + code);
        \\new Promise((resolve, reject) => {
        \\  reject("failed");
        \\  reject?.("failed");
        \\});
        \\new Promise(function (resolve, reject) {
        \\  if (failed) {
        \\    reject(1);
        \\  }
        \\});
        \\const Promise = {
        \\  reject(value) {
        \\    return value;
        \\  }
        \\};
        \\Promise.reject("local");
        \\Promise["reject"]("local");
        \\Promise[`reject`]("local");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 17), helpers.countRule(result, lint.rules.prefer_promise_reject_errors.id));
}

test "does not report prefer-promise-reject-errors for error-like rejection reasons" {
    const source =
        \\Promise.reject(new Error("failed"));
        \\Promise.reject(error);
        \\Promise.reject(Error("failed"));
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_promise_reject_errors.id));
}

test "does not report prefer-promise-reject-errors for dynamic Promise members or nested reject calls" {
    const source =
        \\const suffix = "ject";
        \\const Promise = {
        \\  reject(value) {
        \\    return value;
        \\  }
        \\};
        \\Promise[`re${suffix}`]("dynamic");
        \\Promise?.[`re${suffix}`]("dynamic");
        \\new Promise((resolve, reject) => {
        \\  function nested() {
        \\    reject("nested");
        \\  }
        \\});
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .no_shadow_restricted_names = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_promise_reject_errors.id));
}

test "can disable prefer-promise-reject-errors" {
    const source =
        \\Promise.reject("failed");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .prefer_promise_reject_errors = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_promise_reject_errors.id));
}
