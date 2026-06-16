const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports prefer-spread for apply calls that can use spread syntax" {
    const source =
        \\fn.apply(null, args);
        \\fn.apply(undefined, args);
        \\fn.apply?.(null, args);
        \\fn?.apply(null, args);
        \\obj.method.apply(obj, args);
        \\obj.method.apply?.(obj, args);
        \\obj?.method.apply(obj, args);
        \\obj.method?.apply(obj, args);
        \\this.method.apply(this, args);
        \\obj.nested.method.apply(obj.nested, args);
        \\fn[`apply`](undefined, args);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_useless_call = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 11), helpers.countRule(result, lint.rules.prefer_spread.id));
}

test "does not report prefer-spread when spread conversion is unsafe or covered by no-useless-call" {
    const source =
        \\fn.apply(context, args);
        \\obj.method.apply(other, args);
        \\fn.call(null, first, second);
        \\fn.apply(null, [first, second]);
        \\fn.apply(null, ...args);
        \\fn[`ap${suffix}`](undefined, args);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_useless_call = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_spread.id));
}

test "can disable prefer-spread" {
    const source =
        \\fn.apply(null, args);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .prefer_spread = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.prefer_spread.id));
}
