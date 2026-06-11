const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports guard-for-in for unguarded for-in loops" {
    const source =
        \\for (const key in object) {
        \\  call(key);
        \\}
        \\for (const key in object) call(key);
        \\for (const key in object) {
        \\  if (Object.hasOwn(object, key)) call(key);
        \\  call(key);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_for_in = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.guard_for_in.id));
}

test "allows guard-for-in when the body is an if statement or only contains an if statement" {
    const source =
        \\for (const key in object) if (Object.hasOwn(object, key)) call(key);
        \\for (const key in object) {
        \\  if (Object.hasOwn(object, key)) call(key);
        \\}
        \\for (const key in object);
        \\for (const key in object) {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_for_in = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.guard_for_in.id));
}

test "allows guard-for-in when a leading guard continues before later statements" {
    const source =
        \\for (const key in object) {
        \\  if (!Object.hasOwn(object, key)) continue;
        \\  call(key);
        \\}
        \\for (const key in object) {
        \\  if (!Object.hasOwn(object, key)) {
        \\    continue;
        \\  }
        \\  call(key);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_for_in = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.guard_for_in.id));
}

test "can disable guard-for-in" {
    const source =
        \\for (const key in object) {
        \\  call(key);
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .guard_for_in = false,
        .no_for_in = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.guard_for_in.id));
}
