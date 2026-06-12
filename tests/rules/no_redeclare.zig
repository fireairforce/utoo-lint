const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-redeclare for repeated declarations" {
    const source =
        \\var a = 1;
        \\var a = 2;
        \\
        \\function f() {}
        \\function f() {}
        \\
        \\{
        \\  let b;
        \\  let b;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_redeclare.id));
}

test "reports no-redeclare for script built-in globals" {
    const source =
        \\var Object = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.cjs", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), helpers.countRule(result, lint.rules.no_redeclare.id));
}

test "does not report no-redeclare for distinct scopes and type declarations" {
    const source =
        \\var a = 1;
        \\function f() {
        \\  var a = 2;
        \\}
        \\interface Box {}
        \\interface Box {}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.ts", .{
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_redeclare.id));
}

test "can disable no-redeclare" {
    const source =
        \\var a = 1;
        \\var a = 2;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_redeclare = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_redeclare.id));
}
