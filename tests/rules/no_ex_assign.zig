const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-ex-assign for reassigned catch parameters" {
    const source =
        \\try {
        \\  risky();
        \\} catch (error) {
        \\  error = replacement;
        \\  error++;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_plusplus = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), helpers.countRule(result, lint.rules.no_ex_assign.id));
}

test "does not report no-ex-assign for shadowed variables or member writes" {
    const source =
        \\try {
        \\  risky();
        \\} catch (error) {
        \\  {
        \\    let error = replacement;
        \\    error = other;
        \\  }
        \\  error.message = "handled";
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_ex_assign.id));
}

test "can disable no-ex-assign" {
    const source =
        \\try {
        \\  risky();
        \\} catch (error) {
        \\  error = replacement;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_ex_assign = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_ex_assign.id));
}
