const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-self-assign for equivalent assignment references" {
    const source =
        \\foo = foo;
        \\foo ||= foo;
        \\object.value = object.value;
        \\this.value = this["value"];
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), helpers.countRule(result, lint.rules.no_self_assign.id));
}

test "does not report no-self-assign for different references or effectful objects" {
    const source =
        \\foo = bar;
        \\foo += foo;
        \\object.value = object.other;
        \\getObject().value = getObject().value;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_self_assign.id));
}

test "can disable no-self-assign" {
    const source =
        \\foo = foo;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_self_assign = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_self_assign.id));
}
