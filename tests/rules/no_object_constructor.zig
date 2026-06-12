const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-object-constructor for empty Object calls and constructors" {
    const source =
        \\const first = Object();
        \\const second = new Object();
        \\const third = new (Object)();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_new_object = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_object_constructor.id));
    try std.testing.expectEqualStrings("Do not use the Object constructor.", result.diagnostics[0].message);
}

test "does not report no-object-constructor with arguments or shadowed Object" {
    const source =
        \\const first = Object(value);
        \\const second = new Object(value);
        \\function local(Object) {
        \\  const first = Object();
        \\  const second = new Object();
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_new_object = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_object_constructor.id));
}

test "can disable no-object-constructor" {
    const source =
        \\const first = Object();
        \\const second = new Object();
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_new_object = false,
        .no_object_constructor = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_object_constructor.id));
}
