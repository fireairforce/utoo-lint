const std = @import("std");
const lint = @import("utoo_lint");
const helpers = @import("../helpers.zig");

test "reports no-global-assign for assignments to read-only globals" {
    const source =
        \\Object = null;
        \\NaN = 1;
        \\undefined = 2;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_global_assign.id));
    try std.testing.expectEqualStrings("Read-only global 'Object' should not be modified.", result.diagnostics[0].message);
}

test "reports no-global-assign for updates and destructuring assignments" {
    const source =
        \\Infinity++;
        \\({ Array } = source);
        \\[Map] = source;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), helpers.countRule(result, lint.rules.no_global_assign.id));
}

test "does not report no-global-assign for shadowed names or property writes" {
    const source =
        \\let Object = null;
        \\Object = {};
        \\globalThis.Object = {};
        \\Number.value = 1;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_undef = false,
        .no_unused_vars = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_global_assign.id));
}

test "can disable no-global-assign" {
    const source =
        \\Object = null;
    ;

    var result = try lint.lintSource(std.testing.allocator, source, "fixture.js", .{
        .eol_last = false,
        .no_global_assign = false,
        .no_undef = false,
        .parser_semantic_errors = false,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(!helpers.hasRule(result, lint.rules.no_global_assign.id));
}
