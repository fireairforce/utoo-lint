const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-buffer-constructor for global Buffer calls and constructors" {
    const source =
        \\const first = Buffer("abc");
        \\const second = new Buffer("abc");
        \\const third = new (Buffer)("abc");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_buffer_constructor.id));
}

test "does not report no-buffer-constructor for safe APIs or shadowed Buffer" {
    const source =
        \\const first = Buffer.from("abc");
        \\const second = Buffer.alloc(10);
        \\function local(Buffer) {
        \\  const third = Buffer("abc");
        \\  const fourth = new Buffer("abc");
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_buffer_constructor.id));
}

test "can disable no-buffer-constructor" {
    const source =
        \\const first = Buffer("abc");
        \\const second = new Buffer("abc");
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_buffer_constructor = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_buffer_constructor.id));
}
