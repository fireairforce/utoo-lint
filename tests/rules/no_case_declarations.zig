const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-case-declarations for lexical declarations in switch cases" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    let first = value;
        \\    break;
        \\  case 2:
        \\    const second = value;
        \\    break;
        \\  default:
        \\    class Local {}
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_case_declarations.id));
}

test "does not report no-case-declarations for var or blocked declarations" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    var first = value;
        \\    break;
        \\  case 2: {
        \\    const second = value;
        \\    break;
        \\  }
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_case_declarations.id));
}

test "can disable no-case-declarations" {
    const source =
        \\switch (value) {
        \\  case 1:
        \\    const first = value;
        \\}
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .no_case_declarations = false,
        .no_unused_vars = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_case_declarations.id));
}
