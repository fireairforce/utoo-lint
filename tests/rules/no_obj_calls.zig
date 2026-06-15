const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-obj-calls for global object calls" {
    const source =
        \\Math();
        \\JSON();
        \\Reflect();
        \\Atomics();
        \\Intl();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_obj_calls.id));
}

test "reports no-obj-calls for globalThis object member calls" {
    const source =
        \\globalThis.Math();
        \\globalThis["JSON"]();
        \\globalThis[`Reflect`]();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_obj_calls.id));
}

test "reports no-obj-calls for global object constructors" {
    const source =
        \\new Math();
        \\new JSON();
        \\new Reflect();
        \\new Atomics();
        \\new Intl();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), helpers.countRule(result, lint.rules.no_obj_calls.id));
}

test "reports no-obj-calls for globalThis object member constructors" {
    const source =
        \\new globalThis.Math();
        \\new globalThis["JSON"]();
        \\new globalThis[`Reflect`]();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_new = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_obj_calls.id));
}

test "does not report no-obj-calls for member calls allowed globals or shadowed names" {
    const source =
        \\Math.max(1, 2);
        \\JSON.parse("{}");
        \\Temporal();
        \\new Temporal();
        \\window.Math();
        \\globalThis[`Ma${suffix}`]();
        \\function run(Math, JSON) {
        \\  Math();
        \\  new JSON();
        \\}
        \\function local(globalThis) {
        \\  globalThis.Math();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_empty_function = false,
        .no_new = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_obj_calls.id));
}

test "can disable no-obj-calls" {
    const source =
        \\Math();
        \\new JSON();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_obj_calls = false,
        .no_new = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_obj_calls.id));
}
