const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-useless-call for unnecessary call expressions" {
    const source =
        \\foo.call(undefined);
        \\foo.call(null, a, b);
        \\obj.foo.call(obj, a);
        \\this.foo.call(this, a);
        \\obj.foo.bar.call(obj.foo, a);
        \\foo["call"](undefined, a);
        \\foo.call(void 0, a);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.no_useless_call.id));
}

test "reports no-useless-call for unnecessary apply expressions with array arguments" {
    const source =
        \\foo.apply(undefined, []);
        \\foo.apply(null, [a, b]);
        \\obj.foo.apply(obj, [a]);
        \\this.foo.apply(this, [a]);
        \\obj.foo["apply"](obj, [a]);
        \\foo.apply(undefined, [, a]);
        \\foo.apply(void 0, [a]);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 7), helpers.countRule(result, lint.rules.no_useless_call.id));
}

test "does not report no-useless-call when this binding or arguments are meaningful" {
    const source =
        \\foo.call(obj, a);
        \\obj.foo.call(other, a);
        \\getObj().foo.call(getObj(), a);
        \\foo.apply(undefined, args);
        \\obj.foo.apply(obj, args);
        \\foo.apply(obj, [a]);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_call.id));
}

test "can disable no-useless-call" {
    const source =
        \\foo.call(undefined, a);
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_useless_call = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_useless_call.id));
}
